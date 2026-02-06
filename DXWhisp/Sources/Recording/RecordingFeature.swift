import ComposableArchitecture
import DXWhispKit
import Foundation

@Reducer
public struct RecordingFeature: Sendable {
    public enum PostRecordingState: Equatable, Sendable {
        case transcribing
        case completed(VoiceNote)
        case failed(String)
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var recordingState: RecordingState = .idle
        public var currentDuration: TimeInterval = 0
        public var audioLevel: Float = 0
        public var permissionGranted: Bool?
        public var error: String?
        public var postRecording: PostRecordingState?

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case recordButtonTapped
        case permissionResponse(Bool)
        case timerTicked(audioLevel: Float)
        case recordingFinished(Result<URL, Error>)
        case dismissError
        case viewNoteTapped
        case newRecordingTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable {
            case recordingCompleted(URL, TimeInterval)
            case viewNote(VoiceNote)
        }
    }

    @Dependency(\.audioRecorder) var audioRecorder
    @Dependency(\.continuousClock) var clock
    @Dependency(\.haptic) var haptic

    private enum CancelID { case timer }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.permissionGranted == nil else { return .none }
                return .run { send in
                    let granted = await audioRecorder.requestPermission()
                    if granted {
                        try? await audioRecorder.prepareSession()
                    }
                    await send(.permissionResponse(granted))
                }

            case .recordButtonTapped:
                switch state.recordingState {
                case .idle:
                    guard state.permissionGranted == true else {
                        state.error = L10n.Recording.micRequired
                        return .none
                    }
                    state.postRecording = nil
                    state.recordingState = .recording(duration: 0)
                    state.currentDuration = 0
                    return .merge(
                        .run { @MainActor _ in haptic.impact(.medium) },
                        .run { [audioRecorder] send in
                            do {
                                try await audioRecorder.startRecording()
                            } catch {
                                await send(.recordingFinished(.failure(error)))
                                return
                            }
                            for await _ in clock.timer(interval: .milliseconds(100)) {
                                let level = audioRecorder.currentAudioLevel()
                                await send(.timerTicked(audioLevel: level))
                            }
                        }
                        .cancellable(id: CancelID.timer, cancelInFlight: true)
                    )

                case .recording:
                    let duration = state.currentDuration
                    state.recordingState = .processing
                    state.audioLevel = 0
                    return .merge(
                        .run { @MainActor _ in haptic.notification(.success) },
                        .cancel(id: CancelID.timer),
                        .run { send in
                            do {
                                let url = try await audioRecorder.stopRecording()
                                await send(.delegate(.recordingCompleted(url, duration)))
                            } catch {
                                await send(.recordingFinished(.failure(error)))
                            }
                        }
                    )

                case .processing:
                    return .none
                }

            case let .permissionResponse(granted):
                state.permissionGranted = granted
                if !granted {
                    state.error = L10n.Recording.micDenied
                }
                return .none

            case let .timerTicked(audioLevel: level):
                state.currentDuration += 0.1
                state.audioLevel = level
                state.recordingState = .recording(duration: state.currentDuration)
                return .none

            case .recordingFinished(.success):
                // Parent handles state transitions via delegate(.recordingCompleted)
                return .none

            case let .recordingFinished(.failure(error)):
                state.recordingState = .idle
                state.error = error.localizedDescription
                return .cancel(id: CancelID.timer)

            case .viewNoteTapped:
                guard case .completed(let note) = state.postRecording else { return .none }
                return .send(.delegate(.viewNote(note)))

            case .newRecordingTapped:
                state.recordingState = .idle
                state.currentDuration = 0
                state.audioLevel = 0
                state.postRecording = nil
                state.error = nil
                return .none

            case .delegate:
                return .none

            case .dismissError:
                state.error = nil
                return .none
            }
        }
    }
}
