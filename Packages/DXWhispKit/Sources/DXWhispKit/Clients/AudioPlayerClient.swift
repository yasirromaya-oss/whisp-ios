import AVFoundation
import Dependencies
import Foundation
import os

public struct AudioPlayerClient: Sendable {
    public var play: @Sendable (URL) async throws -> AsyncStream<Void>
    public var pause: @Sendable () async -> Void
    public var resume: @Sendable () async -> Void
    public var seek: @Sendable (TimeInterval) async -> Void
    public var currentTime: @Sendable () async -> TimeInterval

    public init(
        play: @escaping @Sendable (URL) async throws -> AsyncStream<Void>,
        pause: @escaping @Sendable () async -> Void,
        resume: @escaping @Sendable () async -> Void,
        seek: @escaping @Sendable (TimeInterval) async -> Void,
        currentTime: @escaping @Sendable () async -> TimeInterval
    ) {
        self.play = play
        self.pause = pause
        self.resume = resume
        self.seek = seek
        self.currentTime = currentTime
    }
}

extension AudioPlayerClient: DependencyKey {
    public static let liveValue: AudioPlayerClient = {
        let live = LiveAudioPlayerClient.shared
        return AudioPlayerClient(
            play: { try await live.play(url: $0) },
            pause: { await live.pause() },
            resume: { await live.resume() },
            seek: { await live.seek($0) },
            currentTime: { await live.currentTime() }
        )
    }()

    public static let testValue = AudioPlayerClient(
        play: { _ in AsyncStream { $0.yield(); $0.finish() } },
        pause: {},
        resume: {},
        seek: { _ in },
        currentTime: { 0 }
    )
}

public extension DependencyValues {
    var audioPlayer: AudioPlayerClient {
        get { self[AudioPlayerClient.self] }
        set { self[AudioPlayerClient.self] = newValue }
    }
}

// MARK: - Live implementation (AVFoundation)

/// @unchecked Sendable: All mutable state (`player`, `finishContinuation`)
/// is protected by `lock`.
private final class LiveAudioPlayerClient: NSObject, AVAudioPlayerDelegate, @unchecked Sendable {
    static let shared = LiveAudioPlayerClient()
    private static let logger = Logger(subsystem: "me.yasirromaya.whisp.kit", category: "AudioPlayer")

    private let lock = NSLock()
    private var player: AVAudioPlayer?
    private var finishContinuation: AsyncStream<Void>.Continuation?

    private override init() {
        super.init()
    }

    func play(url: URL) async throws -> AsyncStream<Void> {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(true)

        // Extract references under lock, then tear down outside the lock.
        // stop() can fire the delegate synchronously, and NSLock is
        // non-reentrant — calling stop() while holding the lock deadlocks.
        let (oldContinuation, oldPlayer) = lock.withLock {
            let old = (finishContinuation, player)
            finishContinuation = nil
            player = nil
            return old
        }

        oldPlayer?.stop()
        oldContinuation?.finish()

        // Create new stream/continuation pair for this playback session
        let (stream, continuation) = AsyncStream<Void>.makeStream()

        let newPlayer = try AVAudioPlayer(contentsOf: url)
        newPlayer.delegate = self
        newPlayer.prepareToPlay()

        lock.withLock {
            self.player = newPlayer
            self.finishContinuation = continuation
        }

        // play() AFTER storing continuation — the delegate may fire
        // synchronously on very short files; it must find the continuation.
        guard newPlayer.play() else {
            // play() failed — clean up and signal completion so the
            // caller's `for await` doesn't hang forever.
            lock.withLock {
                self.player = nil
                self.finishContinuation = nil
            }
            continuation.finish()
            return stream
        }

        return stream
    }

    // Extract player reference under lock, then call methods outside the lock.
    // AVAudioPlayer methods may synchronously fire the delegate, which also
    // acquires the lock — calling them under the lock would deadlock (NSLock
    // is non-reentrant).
    func pause() async {
        let p = lock.withLock { player }
        p?.pause()
    }

    func resume() async {
        let p = lock.withLock { player }
        p?.play()
    }

    func seek(_ time: TimeInterval) async {
        let p = lock.withLock { player }
        p?.currentTime = time
    }

    func currentTime() async -> TimeInterval {
        lock.withLock { player?.currentTime ?? 0 }
    }

    /// nonisolated because AVAudioPlayerDelegate methods are called from an unknown thread.
    /// All mutable state access is protected by `lock`.
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        lock.lock()
        let cont = finishContinuation
        finishContinuation = nil
        self.player = nil
        lock.unlock()

        cont?.yield()
        cont?.finish()

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Self.logger.warning("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }
}
