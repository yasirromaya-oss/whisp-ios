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
    duration: 10,
    transcription: Transcription(text: "Hello world"),
    insights: Insights(summary: "A greeting", keyPoints: ["Hello"])
)

@MainActor
struct AppFeatureTests {
    @Test func tabChange() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.tabChanged(.settings)) {
            $0.tab = .settings
        }
        await store.send(.tabChanged(.record)) {
            $0.tab = .record
        }
    }

    @Test func transcriptionCompletedAddsNoteAndSetsCompleted() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }
        await store.send(.transcriptionCompleted(sampleNote)) {
            $0.notesList.notes = [sampleNote]
            $0.notesList.recomputeFilteredNotes()
            $0.recording.postRecording = .completed(sampleNote)
        }
    }

    @Test func noteTappedPresentsDetail() async {
        var state = AppFeature.State()
        state.notesList.notes = [sampleNote]
        state.notesList.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.notesList(.noteTapped(sampleNote))) {
            $0.currentNote = NoteDetailFeature.State(note: sampleNote)
        }
    }

    @Test func dismissNoteDetail() async {
        var state = AppFeature.State()
        state.currentNote = NoteDetailFeature.State(note: sampleNote)
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.dismissNoteDetail) {
            $0.currentNote = nil
        }
    }

    @Test func dismissError() async {
        var state = AppFeature.State()
        state.error = "Something went wrong"
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.dismissError) {
            $0.error = nil
        }
    }

    @Test func transcriptionFailedSetsPostRecordingFailed() async {
        var state = AppFeature.State()
        state.recording.postRecording = .transcribing
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.transcriptionFailed("Transcription timed out")) {
            $0.recording.postRecording = .failed("Transcription timed out")
        }
    }

    @Test func recordingCompletedStaysOnRecordTabAndProcesses() async {
        let testURL = URL(fileURLWithPath: "/tmp/test.m4a")
        var state = AppFeature.State()
        state.tab = .record
        state.recording.recordingState = .processing
        state.recording.currentDuration = 5.0
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.transcription.transcribe = { _ in Transcription(text: "Hello") }
            $0.transcription.extractInsights = { _ in Insights(summary: "Greeting") }
            $0.persistence.saveNote = { _ in }
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
        let expectedNote = VoiceNote(
            id: UUID(0),
            createdAt: Date(timeIntervalSince1970: 0),
            title: "Hello",
            audioFilename: testURL.lastPathComponent,
            duration: 5.0,
            transcription: Transcription(text: "Hello"),
            insights: Insights(summary: "Greeting")
        )
        await store.send(.recording(.delegate(.recordingCompleted(testURL, 5.0)))) {
            $0.recording.recordingState = .idle
            $0.recording.currentDuration = 0
            $0.recording.postRecording = .transcribing
        }
        await store.receive(\.processRecording)
        await store.receive(\.transcriptionCompleted) {
            $0.notesList.notes = [expectedNote]
            $0.notesList.recomputeFilteredNotes()
            $0.recording.postRecording = .completed(expectedNote)
        }
    }

    @Test func processRecordingFailureSetsPostRecordingError() async {
        let testURL = URL(fileURLWithPath: "/tmp/test.m4a")
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.transcription.transcribe = { _ in
                throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Recognition failed"])
            }
            $0.uuid = .incrementing
            $0.date = .constant(Date(timeIntervalSince1970: 0))
        }
        await store.send(.processRecording(testURL, 5.0))
        await store.receive(\.transcriptionFailed) {
            $0.recording.postRecording = .failed("Recognition failed")
        }
    }

    @Test func noteDeletedFromDetailRemovesFromListAndClearsPostRecording() async {
        var state = AppFeature.State()
        state.notesList.notes = [sampleNote]
        state.notesList.recomputeFilteredNotes()
        state.currentNote = NoteDetailFeature.State(note: sampleNote)
        state.recording.postRecording = .completed(sampleNote)
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.noteDetail(.presented(.delegate(.noteDeleted(sampleNote.id))))) {
            $0.notesList.notes = []
            $0.notesList.recomputeFilteredNotes()
            $0.currentNote = nil
            $0.recording.postRecording = nil
        }
    }

    @Test func viewNoteTappedPresentsDetail() async {
        var state = AppFeature.State()
        state.recording.postRecording = .completed(sampleNote)
        state.notesList.notes = [sampleNote]
        state.notesList.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.recording(.delegate(.viewNote(sampleNote)))) {
            $0.currentNote = NoteDetailFeature.State(note: sampleNote)
        }
    }

    @Test func noteUpdatedSyncsPostRecording() async {
        var state = AppFeature.State()
        state.notesList.notes = [sampleNote]
        state.notesList.recomputeFilteredNotes()
        state.currentNote = NoteDetailFeature.State(note: sampleNote)
        state.recording.postRecording = .completed(sampleNote)
        var updatedNote = sampleNote
        updatedNote.title = "Updated title"
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.noteDetail(.presented(.delegate(.noteUpdated(updatedNote))))) {
            $0.notesList.notes[id: sampleNote.id] = updatedNote
            $0.notesList.recomputeFilteredNotes()
            $0.recording.postRecording = .completed(updatedNote)
        }
    }
}
