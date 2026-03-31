import ComposableArchitecture
import DXWhispKit
import Foundation
import Testing

@testable import DXWhisp

private let sampleNote = VoiceNote(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    createdAt: Date(timeIntervalSince1970: 1_000),
    title: "Test note",
    audioFilename: "test.m4a",
    duration: 10
)

@MainActor
struct RecordingFeatureTests {
    @Test func onAppearRequestsPermission() async {
        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.audioRecorder.requestPermission = { true }
            $0.audioRecorder.prepareSession = {}
        }
        await store.send(.onAppear)
        await store.receive(\.permissionResponse) {
            $0.permissionGranted = true
        }
    }

    @Test func onAppearSkipsIfAlreadyChecked() async {
        var state = RecordingFeature.State()
        state.permissionGranted = true
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.onAppear)
    }

    @Test func permissionDeniedShowsError() async {
        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        } withDependencies: {
            $0.audioRecorder.requestPermission = { false }
        }
        await store.send(.onAppear)
        await store.receive(\.permissionResponse) {
            $0.permissionGranted = false
            $0.error = "Microphone access denied. Enable it in Settings \u{2192} DXWhisp \u{2192} Microphone."
        }
    }

    @Test func recordButtonWithoutPermissionShowsError() async {
        var state = RecordingFeature.State()
        state.permissionGranted = false
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.recordButtonTapped) {
            $0.error = "Microphone access required. Enable it in Settings \u{2192} DXWhisp."
        }
    }

    @Test func dismissErrorClearsError() async {
        var state = RecordingFeature.State()
        state.error = "Some error"
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.dismissError) {
            $0.error = nil
        }
    }

    @Test func recordingFinishedSuccessIsNoOp() async {
        var state = RecordingFeature.State()
        state.recordingState = .recording(duration: 5.0)
        state.currentDuration = 5.0
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.recordingFinished(.success(URL(fileURLWithPath: "/tmp/test.m4a"))))
    }

    @Test func recordingFailureResetsAndShowsError() async {
        var state = RecordingFeature.State()
        state.recordingState = .recording(duration: 2.0)
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recording failed"])
        await store.send(.recordingFinished(.failure(error))) {
            $0.recordingState = .idle
            $0.error = "Recording failed"
        }
    }

    @Test func viewNoteTappedSendsDelegate() async {
        var state = RecordingFeature.State()
        state.postRecording = .completed(sampleNote)
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.viewNoteTapped)
        await store.receive(\.delegate.viewNote)
    }

    @Test func viewNoteTappedWithNoCompletedNoteIsNoOp() async {
        let store = TestStore(initialState: RecordingFeature.State()) {
            RecordingFeature()
        }
        await store.send(.viewNoteTapped)
    }

    @Test func newRecordingTappedResetsState() async {
        var state = RecordingFeature.State()
        state.postRecording = .completed(sampleNote)
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.newRecordingTapped) {
            $0.postRecording = nil
            $0.recordingState = .idle
            $0.currentDuration = 0
            $0.error = nil
        }
    }

    @Test func timerTickedUpdatesDurationAndLevel() async {
        var state = RecordingFeature.State()
        state.recordingState = .recording(duration: 0)
        state.currentDuration = 0
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.timerTicked(audioLevel: 0.75)) {
            $0.currentDuration = 0.1
            $0.audioLevel = 0.75
            $0.recordingState = .recording(duration: 0.1)
        }
    }

    @Test func recordButtonStartsRecording() async {
        var state = RecordingFeature.State()
        state.permissionGranted = true
        let clock = TestClock()
        let store = TestStore(initialState: state) {
            RecordingFeature()
        } withDependencies: {
            $0.audioRecorder.startRecording = {}
            $0.audioRecorder.currentAudioLevel = { 0.5 }
            $0.continuousClock = clock
        }
        await store.send(.recordButtonTapped) {
            $0.recordingState = .recording(duration: 0)
            $0.currentDuration = 0
        }
        // Timer fires after recording starts
        await clock.advance(by: .milliseconds(100))
        await store.receive(\.timerTicked) {
            $0.currentDuration = 0.1
            $0.audioLevel = 0.5
            $0.recordingState = .recording(duration: 0.1)
        }
        await store.skipInFlightEffects()
    }

    @Test func recordButtonWhileProcessingIsNoOp() async {
        var state = RecordingFeature.State()
        state.recordingState = .processing
        state.permissionGranted = true
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.recordButtonTapped)
    }

    // MARK: - Subscription Gates

    @Test func freeUserAtLimitShowsPaywall() async {
        var state = RecordingFeature.State()
        state.permissionGranted = true
        state.isPro = false
        state.monthlyRecordingCount = 3
        let store = TestStore(initialState: state) {
            RecordingFeature()
        }
        await store.send(.recordButtonTapped)
        await store.receive(\.delegate.paywallRequested)
    }

    @Test func freeUserUnderLimitCanRecord() async {
        var state = RecordingFeature.State()
        state.permissionGranted = true
        state.isPro = false
        state.monthlyRecordingCount = 2
        let clock = TestClock()
        let store = TestStore(initialState: state) {
            RecordingFeature()
        } withDependencies: {
            $0.audioRecorder.startRecording = {}
            $0.audioRecorder.currentAudioLevel = { 0.5 }
            $0.continuousClock = clock
        }
        await store.send(.recordButtonTapped) {
            $0.recordingState = .recording(duration: 0)
            $0.currentDuration = 0
        }
        await store.skipInFlightEffects()
    }

    @Test func proUserUnlimitedRecordings() async {
        var state = RecordingFeature.State()
        state.permissionGranted = true
        state.isPro = true
        state.monthlyRecordingCount = 100
        let clock = TestClock()
        let store = TestStore(initialState: state) {
            RecordingFeature()
        } withDependencies: {
            $0.audioRecorder.startRecording = {}
            $0.audioRecorder.currentAudioLevel = { 0.5 }
            $0.continuousClock = clock
        }
        await store.send(.recordButtonTapped) {
            $0.recordingState = .recording(duration: 0)
            $0.currentDuration = 0
        }
        await store.skipInFlightEffects()
    }

    @Test func freeRecordingsRemainingComputation() {
        var state = RecordingFeature.State()
        state.monthlyRecordingCount = 0
        #expect(state.freeRecordingsRemaining == 3)

        state.monthlyRecordingCount = 2
        #expect(state.freeRecordingsRemaining == 1)

        state.monthlyRecordingCount = 3
        #expect(state.freeRecordingsRemaining == 0)

        state.monthlyRecordingCount = 10
        #expect(state.freeRecordingsRemaining == 0)
    }
}
