import AVFoundation
import Dependencies
import Foundation
import os

public struct AudioRecorderClient: Sendable {
    public var requestPermission: @Sendable () async -> Bool
    public var prepareSession: @Sendable () async throws -> Void
    public var startRecording: @Sendable () async throws -> Void
    public var stopRecording: @Sendable () async throws -> URL
    /// Returns the current audio level normalized to 0.0–1.0.
    /// Must be called while recording; returns 0 otherwise.
    public var currentAudioLevel: @Sendable () -> Float
}

extension AudioRecorderClient: DependencyKey {
    public static let liveValue = AudioRecorderClient(
        requestPermission: { await AudioRecorder.shared.requestPermission() },
        prepareSession: { try await AudioRecorder.shared.prepareSession() },
        startRecording: { try await AudioRecorder.shared.startRecording() },
        stopRecording: { try await AudioRecorder.shared.stopRecording() },
        currentAudioLevel: { AudioRecorder.shared.currentAudioLevel() }
    )

    public static let testValue = AudioRecorderClient(
        requestPermission: { true },
        prepareSession: {},
        startRecording: {},
        stopRecording: { URL(fileURLWithPath: "/tmp/test.m4a") },
        currentAudioLevel: { 0 }
    )

    #if DEBUG
    /// Screenshot mode: provides a minimal client for UI previews without mic input.
    /// Returns a simulated audio level so the wave animation looks active in screenshots.
    public static let screenshotValue = AudioRecorderClient(
        requestPermission: { true },
        prepareSession: {},
        startRecording: {},
        stopRecording: { URL(fileURLWithPath: "/tmp/screenshot.m4a") },
        currentAudioLevel: {
            let t = CFAbsoluteTimeGetCurrent()
            return Float(0.35 + 0.25 * sin(t * 2.5) + 0.1 * sin(t * 5.3))
        }
    )
    #endif
}

public extension DependencyValues {
    var audioRecorder: AudioRecorderClient {
        get { self[AudioRecorderClient.self] }
        set { self[AudioRecorderClient.self] = newValue }
    }
}

// MARK: - Live Implementation

/// @unchecked Sendable: All mutable state (`recorder`, `recordingURL`,
/// `continuation`, `sessionPrepared`) is protected by `lock`.
private final class AudioRecorder: NSObject, AVAudioRecorderDelegate, @unchecked Sendable {
    static let shared = AudioRecorder()
    private static let logger = Logger(subsystem: "me.yasirromaya.whisp.kit", category: "AudioRecorder")

    private let lock = NSLock()
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var continuation: CheckedContinuation<URL, Error>?
    private var sessionPrepared = false
    private var isStarting = false
    /// URL saved when a system interruption (phone call, Siri) stops
    /// the recorder before the user taps stop.
    private var interruptedRecordingURL: URL?

    func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func prepareSession() async throws {
        let alreadyPrepared = lock.withLock { sessionPrepared }
        guard !alreadyPrepared else { return }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])

        lock.withLock { sessionPrepared = true }
    }

    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()

        let (alreadyRecording, needsSetup) = lock.withLock {
            if recorder != nil || isStarting {
                return (true, false)
            }
            isStarting = true
            return (false, !sessionPrepared)
        }
        guard !alreadyRecording else { return }

        do {
            if needsSetup {
                try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
                lock.withLock { sessionPrepared = true }
            }

            try session.setActive(true)

            let directory = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Audio", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication,
            ])

            let fileURL: URL
            let newRecorder: AVAudioRecorder
            do {
                fileURL = directory.appendingPathComponent("\(UUID().uuidString).m4a")
                newRecorder = try AVAudioRecorder(url: fileURL, settings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 16000,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                ])
            } catch {
                // Recorder init failed — deactivate the session we just activated
                do {
                    try session.setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    Self.logger.warning("Failed to deactivate audio session after recorder init failure: \(error.localizedDescription)")
                }
                throw error
            }
            newRecorder.isMeteringEnabled = true
            newRecorder.delegate = self
            newRecorder.record()

            lock.withLock {
                self.recorder = newRecorder
                recordingURL = fileURL
                interruptedRecordingURL = nil
                isStarting = false
            }
        } catch {
            lock.withLock { isStarting = false }
            throw error
        }
    }

    func stopRecording() async throws -> URL {
        // If a system interruption already stopped the recorder,
        // return the saved URL immediately.
        let interruptedURL: URL? = {
            lock.lock()
            defer { lock.unlock() }
            let url = interruptedRecordingURL
            interruptedRecordingURL = nil
            return url
        }()

        if let url = interruptedURL {
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                Self.logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
            }
            return url
        }

        // Capture recorder reference under the lock
        let capturedRecorder: AVAudioRecorder = try {
            lock.lock()
            defer { lock.unlock() }
            guard let r = self.recorder, recordingURL != nil else {
                throw RecordingError.notRecording
            }
            return r
        }()

        // Note: If the delegate never fires (e.g. recorder deallocated by another
        // codepath), this continuation will hang indefinitely. In practice,
        // AVAudioRecorder.stop() reliably fires audioRecorderDidFinishRecording.
        return try await withCheckedThrowingContinuation { cont in
            lock.lock()
            guard self.continuation == nil else {
                lock.unlock()
                cont.resume(throwing: RecordingError.notRecording)
                return
            }
            self.continuation = cont
            lock.unlock()
            // The delegate may fire synchronously during stop(),
            // so the lock MUST be released before this call.
            capturedRecorder.stop()
        }
    }

    // MARK: - Audio Metering

    /// Returns the current audio power normalized to 0.0–1.0.
    /// Clamps the dB range -50…0 into 0…1 for smooth UI driving.
    func currentAudioLevel() -> Float {
        lock.lock()
        let activeRecorder = recorder
        lock.unlock()

        guard let activeRecorder, activeRecorder.isRecording else { return 0 }
        activeRecorder.updateMeters()
        let power = activeRecorder.averagePower(forChannel: 0)
        // Map -50dB…0dB → 0.0…1.0
        let clamped = max(-50, min(0, power))
        return (clamped + 50) / 50
    }

    // MARK: - AVAudioRecorderDelegate

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully success: Bool) {
        lock.lock()
        let url = recordingURL
        self.recorder = nil
        recordingURL = nil
        let cont = self.continuation
        self.continuation = nil
        // If no continuation is waiting, the recording was interrupted
        // by the system (phone call, Siri). Preserve the URL so
        // stopRecording() can return it later.
        if cont == nil, success, let url {
            interruptedRecordingURL = url
        }
        lock.unlock()

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Self.logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
        }

        guard let cont else { return }

        if success, let url {
            do {
                try FileManager.default.setAttributes(
                    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                    ofItemAtPath: url.path
                )
            } catch {
                Self.logger.warning("Failed to set file protection: \(error.localizedDescription)")
            }
            cont.resume(returning: url)
        } else {
            cont.resume(throwing: RecordingError.saveFailed)
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        lock.lock()
        self.recorder = nil
        recordingURL = nil
        let cont = self.continuation
        self.continuation = nil
        lock.unlock()

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Self.logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
        }

        cont?.resume(throwing: error ?? RecordingError.encodingFailed)
    }
}

// MARK: - Errors

private enum RecordingError: LocalizedError {
    case notRecording
    case saveFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notRecording: "No active recording"
        case .saveFailed: "Failed to save recording"
        case .encodingFailed: "Failed to encode audio"
        }
    }
}
