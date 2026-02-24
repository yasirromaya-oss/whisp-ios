import ComposableArchitecture
import DXWhispKit
import Foundation
import Testing

@testable import DXWhisp

private let testNote = VoiceNote(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    createdAt: Date(timeIntervalSince1970: 1_000),
    title: "Test note",
    audioFilename: "test.m4a",
    duration: 10,
    transcription: Transcription(text: "Hello world"),
    insights: Insights(
        summary: "A greeting",
        actionItems: [
            ActionItem(text: "Do something"),
        ],
        events: [
            ExtractedEvent(title: "Meeting", date: Date(timeIntervalSince1970: 2_000), rawDateText: "tomorrow at 2pm"),
        ],
        keyPoints: ["Hello"]
    )
)

// MARK: - Playback

@MainActor
struct NoteDetailPlaybackTests {
    @Test func playStartsPlaybackAndTimer() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.audioPlayer.play = { _ in AsyncStream { $0.yield(); $0.finish() } }
            $0.audioPlayer.pause = {}
            $0.audioPlayer.currentTime = { 0 }
            $0.continuousClock = TestClock()
        }
        await store.send(.playPauseTapped) {
            $0.isPlaying = true
            $0.playbackSessionActive = true
        }
        await store.receive(\.playbackFinished) {
            $0.isPlaying = false
            $0.playbackSessionActive = false
            $0.playbackProgress = 0
            $0.currentTime = 0
        }
    }

    @Test func pauseStopsPlayback() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isPlaying = true
        state.playbackSessionActive = true
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.audioPlayer.pause = {}
        }
        await store.send(.playPauseTapped) {
            $0.isPlaying = false
            // playbackSessionActive stays true — paused, not stopped
        }
    }

    @Test func playbackFinishedResetsState() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isPlaying = true
        state.playbackSessionActive = true
        state.playbackProgress = 0.5
        state.currentTime = 5.0
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        }
        await store.send(.playbackFinished) {
            $0.isPlaying = false
            $0.playbackSessionActive = false
            $0.playbackProgress = 0
            $0.currentTime = 0
        }
    }

    @Test func playbackFailedShowsError() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isPlaying = true
        state.playbackSessionActive = true
        state.playbackProgress = 0.3
        state.currentTime = 3.0
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        }
        await store.send(.playbackFailed("File not found")) {
            $0.isPlaying = false
            $0.playbackSessionActive = false
            $0.playbackProgress = 0
            $0.currentTime = 0
            $0.errorMessage = "File not found"
        }
    }

    @Test func playErrorSendsPlaybackFailed() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.audioPlayer.play = { _ in throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio error"]) }
            $0.continuousClock = TestClock()
        }
        await store.send(.playPauseTapped) {
            $0.isPlaying = true
            $0.playbackSessionActive = true
        }
        await store.receive(\.playbackFailed) {
            $0.isPlaying = false
            $0.playbackSessionActive = false
            $0.playbackProgress = 0
            $0.currentTime = 0
            $0.errorMessage = "Audio error"
        }
    }

    @Test func resumeAfterPauseDoesNotRestartPlayback() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isPlaying = false
        state.playbackSessionActive = true
        state.currentTime = 5.0
        state.playbackProgress = 0.5
        let resumeCalled = LockIsolated(false)
        let playCalled = LockIsolated(false)
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.audioPlayer.resume = { resumeCalled.setValue(true) }
            $0.audioPlayer.play = { _ in
                playCalled.setValue(true)
                return AsyncStream { $0.finish() }
            }
            $0.audioPlayer.pause = {}
            $0.audioPlayer.currentTime = { 5.0 }
            $0.continuousClock = TestClock()
        }
        await store.send(.playPauseTapped) {
            $0.isPlaying = true
        }
        #expect(resumeCalled.value == true)
        #expect(playCalled.value == false)
        // Pause to clean up timer effect
        await store.send(.playPauseTapped) {
            $0.isPlaying = false
        }
    }

    @Test func seekUpdatesProgressAndTime() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.audioPlayer.seek = { _ in }
        }
        await store.send(.seek(0.5)) {
            $0.playbackProgress = 0.5
            $0.currentTime = 5.0
        }
    }

    @Test func playbackProgressUpdated() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isPlaying = true
        state.playbackSessionActive = true
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        }
        await store.send(.playbackProgressUpdated(currentTime: 3.0, progress: 0.3)) {
            $0.currentTime = 3.0
            $0.playbackProgress = 0.3
        }
    }
}

// MARK: - Delete

@MainActor
struct NoteDetailDeleteTests {
    @Test func deleteButtonShowsConfirmation() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        }
        await store.send(.deleteButtonTapped) {
            $0.showDeleteConfirmation = true
        }
    }

    @Test func confirmDeleteSucceeds() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { _ in }
        }
        await store.send(.confirmDelete)
        await store.receive(\.delegate.noteDeleted)
    }

    @Test func confirmDeleteFails() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.confirmDelete)
        await store.receive(\.deleteFailed) {
            $0.errorMessage = "We couldn't delete this note. Please try again."
        }
    }
}

// MARK: - Export

@MainActor
struct NoteDetailExportTests {
    @Test func exportToRemindersSucceeds() async {
        let item = testNote.insights!.actionItems[0]
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.eventKit.requestRemindersAccess = { true }
            $0.eventKit.addReminder = { _, _ in }
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.exportToReminders(item)) {
            let updatedItem = ActionItem(
                id: item.id,
                text: item.text,
                isCompleted: item.isCompleted,
                exportedToReminders: true
            )
            updateActionItem(&$0.note, updatedItem)
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func exportToRemindersFails() async {
        let item = testNote.insights!.actionItems[0]
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.eventKit.requestRemindersAccess = { true }
            $0.eventKit.addReminder = { _, _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.exportToReminders(item)) {
            let updatedItem = ActionItem(
                id: item.id,
                text: item.text,
                isCompleted: item.isCompleted,
                exportedToReminders: true
            )
            updateActionItem(&$0.note, updatedItem)
        }
        await store.receive(\.exportToRemindersFailed) {
            // Reverts back to original item
            updateActionItem(&$0.note, item)
            $0.errorMessage = "We couldn't add that to Reminders. Check that Reminders is allowed in Settings → DXWhisp and try again."
        }
    }

    @Test func exportToCalendarSucceeds() async {
        let event = testNote.insights!.events[0]
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.eventKit.requestCalendarAccess = { true }
            $0.eventKit.addCalendarEvent = { _, _, _ in }
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.exportToCalendar(event)) {
            let updatedEvent = ExtractedEvent(
                id: event.id,
                title: event.title,
                date: event.date,
                rawDateText: event.rawDateText,
                exportedToCalendar: true
            )
            updateEvent(&$0.note, updatedEvent)
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func exportToCalendarFails() async {
        let event = testNote.insights!.events[0]
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.eventKit.requestCalendarAccess = { true }
            $0.eventKit.addCalendarEvent = { _, _, _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.exportToCalendar(event)) {
            let updatedEvent = ExtractedEvent(
                id: event.id,
                title: event.title,
                date: event.date,
                rawDateText: event.rawDateText,
                exportedToCalendar: true
            )
            updateEvent(&$0.note, updatedEvent)
        }
        await store.receive(\.exportToCalendarFailed) {
            updateEvent(&$0.note, event)
            $0.errorMessage = "We couldn't add that to Calendar. Check that Calendar is allowed in Settings → DXWhisp and try again."
        }
    }
}

// MARK: - Toggle Action Item

@MainActor
struct NoteDetailActionItemTests {
    @Test func toggleActionItemCompletedSucceeds() async {
        let item = testNote.insights!.actionItems[0]
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.toggleActionItemCompleted(item.id)) {
            $0.note.insights?.actionItems[0].isCompleted = true
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func toggleActionItemCompletedFails() async {
        let item = testNote.insights!.actionItems[0]
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.toggleActionItemCompleted(item.id)) {
            $0.note.insights?.actionItems[0].isCompleted = true
        }
        await store.receive(\.toggleActionItemFailed) {
            $0.note.insights?.actionItems[0].isCompleted = false
            $0.errorMessage = "We couldn't save that change. Please try again."
        }
    }

    @Test func toggleActionItemInvalidIdIsNoOp() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        }
        await store.send(.toggleActionItemCompleted(UUID()))
    }
}

// MARK: - Error Dismissal

@MainActor
struct NoteDetailErrorTests {
    @Test func dismissErrorClearsMessage() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.errorMessage = "Something went wrong"
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        }
        await store.send(.dismissError) {
            $0.errorMessage = nil
        }
    }
}

// MARK: - Biometric Auth

private let lockedNote = VoiceNote(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
    createdAt: Date(timeIntervalSince1970: 1_000),
    title: "Locked note",
    audioFilename: "locked.m4a",
    duration: 10,
    isLocked: true
)

@MainActor
struct NoteDetailBiometricTests {
    @Test func lockedNoteRequiresAuth() {
        let state = NoteDetailFeature.State(note: lockedNote)
        #expect(state.isAuthenticated == false)
        #expect(state.note.isLocked == true)
    }

    @Test func unlockedNoteIsAuthenticated() {
        let state = NoteDetailFeature.State(note: testNote)
        #expect(state.isAuthenticated == true)
    }

    @Test func authenticationSucceededUnlocksContent() async {
        let state = NoteDetailFeature.State(note: lockedNote)
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.biometric.authenticate = { _ in true }
        }
        await store.send(.authenticationRequired)
        await store.receive(\.authenticationSucceeded) {
            $0.isAuthenticated = true
        }
    }

    @Test func authenticationFailedShowsError() async {
        let state = NoteDetailFeature.State(note: lockedNote)
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.biometric.authenticate = { _ in throw NSError(domain: "LAError", code: -2, userInfo: [NSLocalizedDescriptionKey: "User canceled"]) }
        }
        await store.send(.authenticationRequired)
        await store.receive(\.authenticationFailed) {
            $0.isAuthenticated = false
            $0.errorMessage = "User canceled"
        }
    }

    @Test func toggleLockLocksNote() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.toggleLock) {
            $0.note.isLocked = true
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func toggleLockUnlocksNote() async {
        let state = NoteDetailFeature.State(note: lockedNote)
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.toggleLock) {
            $0.note.isLocked = false
            $0.isAuthenticated = true
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func toggleLockFailedRevertsLockState() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.toggleLock) {
            $0.note.isLocked = true
        }
        await store.receive(\.toggleLockFailed) {
            $0.note.isLocked = false
            $0.errorMessage = "We couldn't update the lock. Please try again."
        }
    }

    @Test func unlockFailedRevertsToLocked() async {
        let state = NoteDetailFeature.State(note: lockedNote)
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.toggleLock) {
            $0.note.isLocked = false
            $0.isAuthenticated = true
        }
        await store.receive(\.toggleLockFailed) {
            $0.note.isLocked = true
            $0.errorMessage = "We couldn't update the lock. Please try again."
        }
    }
}

// MARK: - Playback Edge Cases

@MainActor
struct NoteDetailPlaybackEdgeCaseTests {
    @Test func playbackTimerTickedQueriesCurrentTime() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isPlaying = true
        state.playbackSessionActive = true
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.audioPlayer.currentTime = { 5.0 }
        }
        await store.send(.playbackTimerTicked)
        await store.receive(\.playbackProgressUpdated) {
            $0.currentTime = 5.0
            $0.playbackProgress = 0.5
        }
    }

    @Test func seekWhilePausedDoesNotResume() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isPlaying = false
        state.playbackSessionActive = true
        state.currentTime = 3.0
        state.playbackProgress = 0.3
        let resumeCalled = LockIsolated(false)
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.audioPlayer.seek = { _ in }
            $0.audioPlayer.resume = { resumeCalled.setValue(true) }
        }
        await store.send(.seek(0.7)) {
            $0.playbackProgress = 0.7
            $0.currentTime = 7.0
        }
        #expect(resumeCalled.value == false)
    }

    @Test func zeroDurationNoteDoesNotDivideByZero() async {
        let zeroDurationNote = VoiceNote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            createdAt: Date(timeIntervalSince1970: 1_000),
            title: "Zero duration",
            audioFilename: "zero.m4a",
            duration: 0
        )
        var state = NoteDetailFeature.State(note: zeroDurationNote)
        state.isPlaying = true
        state.playbackSessionActive = true
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.audioPlayer.currentTime = { 0 }
        }
        await store.send(.playbackTimerTicked)
        await store.receive(\.playbackProgressUpdated)
    }
}

// MARK: - Transcript Editing

@MainActor
struct NoteDetailTranscriptEditingTests {
    @Test func editTranscriptTappedStartsEditing() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        }
        await store.send(.editTranscriptTapped) {
            $0.isEditingTranscript = true
            $0.editedTranscriptText = "Hello world"
        }
    }

    @Test func editTranscriptWithNoTranscriptionIsNoOp() async {
        let noteWithoutTranscript = VoiceNote(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            createdAt: Date(timeIntervalSince1970: 1_000),
            title: "No transcript",
            audioFilename: "no-transcript.m4a",
            duration: 10
        )
        let store = TestStore(initialState: NoteDetailFeature.State(note: noteWithoutTranscript)) {
            NoteDetailFeature()
        }
        await store.send(.editTranscriptTapped)
    }

    @Test func cancelEditTranscriptClearsState() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isEditingTranscript = true
        state.editedTranscriptText = "Edited text"
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        }
        await store.send(.cancelEditTranscript) {
            $0.isEditingTranscript = false
            $0.editedTranscriptText = ""
        }
    }

    @Test func saveTranscriptUpdatesAndReExtracts() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isEditingTranscript = true
        state.editedTranscriptText = "Updated transcript text"
        let newInsights = Insights(summary: "Updated summary")
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
            $0.transcription.extractInsights = { _ in newInsights }
        }
        await store.send(.saveTranscript) {
            $0.note.transcription = Transcription(text: "Updated transcript text")
            $0.isEditingTranscript = false
            $0.editedTranscriptText = ""
            $0.isReExtractingInsights = true
        }
        await store.receive(\.delegate.noteUpdated)
        await store.receive(\.reExtractInsightsCompleted) {
            $0.isReExtractingInsights = false
            $0.note.insights = Insights(
                summary: "Updated summary",
                actionItems: [],
                events: [],
                keyPoints: ["Hello"]
            )
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func saveTranscriptHandlesExtractionFailure() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isEditingTranscript = true
        state.editedTranscriptText = "Updated text"
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
            $0.transcription.extractInsights = { _ in throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Extraction failed"]) }
        }
        await store.send(.saveTranscript) {
            $0.note.transcription = Transcription(text: "Updated text")
            $0.isEditingTranscript = false
            $0.editedTranscriptText = ""
            $0.isReExtractingInsights = true
        }
        await store.receive(\.delegate.noteUpdated)
        await store.receive(\.reExtractInsightsFailed) {
            $0.isReExtractingInsights = false
            $0.errorMessage = "Couldn't re-extract insights: Extraction failed"
        }
    }

    @Test func saveTranscriptPersistFailedResetsSpinnerAndShowsError() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isReExtractingInsights = true
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        }
        await store.send(.saveTranscriptPersistFailed("Disk full")) {
            $0.isReExtractingInsights = false
            $0.errorMessage = "Couldn't save transcript: Disk full"
        }
    }

    @Test func reExtractInsightsPersistFailedShowsError() async {
        let store = TestStore(initialState: NoteDetailFeature.State(note: testNote)) {
            NoteDetailFeature()
        }
        await store.send(.reExtractInsightsPersistFailed("Disk full")) {
            $0.errorMessage = "Couldn't save insights: Disk full"
        }
    }

    @Test func reExtractInsightsCompletedPersistsAndDelegates() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isReExtractingInsights = true
        let newInsights = Insights(summary: "New summary", keyPoints: ["Point A"])
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.reExtractInsightsCompleted(newInsights)) {
            $0.isReExtractingInsights = false
            $0.note.insights = newInsights
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func saveTranscriptPreservesSegmentsAndSpeakerTurns() async {
        let segments = [
            TranscriptionSegment(text: "Hello", timestamp: 0, duration: 1.0, confidence: 0.95),
            TranscriptionSegment(text: "world", timestamp: 1.0, duration: 0.8, confidence: 0.90),
        ]
        let speakerTurns = [
            SpeakerTurn(speakerLabel: "Speaker 1", text: "Hello world", startTime: 0, endTime: 1.8),
        ]
        var noteWithSegments = testNote
        noteWithSegments.transcription = Transcription(text: "Hello world", segments: segments, speakerTurns: speakerTurns)

        var state = NoteDetailFeature.State(note: noteWithSegments)
        state.isEditingTranscript = true
        state.editedTranscriptText = "Hello world edited"
        let newInsights = Insights(summary: "Edited summary")
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
            $0.transcription.extractInsights = { _ in newInsights }
        }
        await store.send(.saveTranscript) {
            // Segments and speakerTurns are preserved even though text changed
            $0.note.transcription = Transcription(text: "Hello world edited", segments: segments, speakerTurns: speakerTurns)
            $0.isEditingTranscript = false
            $0.editedTranscriptText = ""
            $0.isReExtractingInsights = true
        }
        await store.receive(\.delegate.noteUpdated)
        await store.receive(\.reExtractInsightsCompleted) {
            $0.isReExtractingInsights = false
            $0.note.insights = Insights(
                summary: "Edited summary",
                actionItems: [],
                events: [],
                keyPoints: ["Hello"]
            )
        }
        await store.receive(\.delegate.noteUpdated)
    }
}

// MARK: - Re-extraction Merge Preservation

@MainActor
struct NoteDetailMergePreservationTests {
    @Test func reExtractPreservesActionItemCompletion() async {
        // Set up a note with a completed action item
        var noteWithCompleted = testNote
        let existingId = noteWithCompleted.insights!.actionItems[0].id
        noteWithCompleted.insights?.actionItems[0] = ActionItem(
            id: existingId,
            text: "Do something",
            isCompleted: true,
            exportedToReminders: true
        )
        var state = NoteDetailFeature.State(note: noteWithCompleted)
        state.isReExtractingInsights = true
        let originalItemId = noteWithCompleted.insights!.actionItems[0].id

        // New insights have same text but fresh (uncompleted) items
        let newInsights = Insights(
            summary: "Updated summary",
            actionItems: [
                ActionItem(text: "Do something"),
            ],
            events: [],
            keyPoints: ["New point"]
        )
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.reExtractInsightsCompleted(newInsights)) {
            $0.isReExtractingInsights = false
            // Merged: should preserve id, isCompleted, exportedToReminders
            $0.note.insights = Insights(
                summary: "Updated summary",
                actionItems: [
                    ActionItem(id: originalItemId, text: "Do something", isCompleted: true, exportedToReminders: true),
                ],
                events: [],
                keyPoints: ["New point"]
            )
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func reExtractPreservesEventExportState() async {
        var state = NoteDetailFeature.State(note: testNote)
        state.isReExtractingInsights = true
        let originalEventId = testNote.insights!.events[0].id
        // Mark original event as exported
        state.note.insights?.events[0] = ExtractedEvent(
            id: originalEventId,
            title: "Meeting",
            date: Date(timeIntervalSince1970: 2_000),
            rawDateText: "tomorrow at 2pm",
            exportedToCalendar: true
        )

        let newInsights = Insights(
            summary: "New summary",
            actionItems: [],
            events: [
                ExtractedEvent(title: "Meeting", date: Date(timeIntervalSince1970: 3_000), rawDateText: "next week"),
            ],
            keyPoints: []
        )
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.reExtractInsightsCompleted(newInsights)) {
            $0.isReExtractingInsights = false
            // Merged: preserves id, exportedToCalendar; uses new date
            $0.note.insights = Insights(
                summary: "New summary",
                actionItems: [],
                events: [
                    ExtractedEvent(
                        id: originalEventId,
                        title: "Meeting",
                        date: Date(timeIntervalSince1970: 3_000),
                        rawDateText: "next week",
                        exportedToCalendar: true
                    ),
                ],
                keyPoints: ["Hello"]
            )
        }
        await store.receive(\.delegate.noteUpdated)
    }

    @Test func reExtractWithNoOldInsightsUsesNewDirectly() async {
        var noteWithoutInsights = testNote
        noteWithoutInsights.insights = nil
        var state = NoteDetailFeature.State(note: noteWithoutInsights)
        state.isReExtractingInsights = true
        let newInsights = Insights(summary: "Fresh summary", keyPoints: ["Point"])
        let store = TestStore(initialState: state) {
            NoteDetailFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.reExtractInsightsCompleted(newInsights)) {
            $0.isReExtractingInsights = false
            $0.note.insights = newInsights
        }
        await store.receive(\.delegate.noteUpdated)
    }
}

// MARK: - Helpers (mirror private helpers from NoteDetailFeature)

private func updateActionItem(_ note: inout VoiceNote, _ item: ActionItem) {
    guard let index = note.insights?.actionItems.firstIndex(where: { $0.id == item.id }) else { return }
    note.insights?.actionItems[index] = item
}

private func updateEvent(_ note: inout VoiceNote, _ event: ExtractedEvent) {
    guard let index = note.insights?.events.firstIndex(where: { $0.id == event.id }) else { return }
    note.insights?.events[index] = event
}
