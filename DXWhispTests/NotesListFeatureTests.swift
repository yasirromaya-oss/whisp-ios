import ConcurrencyExtras
import ComposableArchitecture
import DXWhispKit
import Foundation
import Testing

@testable import DXWhisp

private let note1 = VoiceNote(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    createdAt: Date(timeIntervalSince1970: 1_000),
    title: "Meeting notes",
    audioFilename: "a.m4a",
    duration: 30,
    transcription: Transcription(text: "Discuss project timeline")
)

private let note2 = VoiceNote(
    id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
    createdAt: Date(timeIntervalSince1970: 2_000),
    title: "Grocery list",
    audioFilename: "b.m4a",
    duration: 15
)

@MainActor
struct NotesListFeatureTests {
    @Test func onAppearLoadsNotes() async {
        let cleanupCalled = LockIsolated(false)
        let store = TestStore(initialState: NotesListFeature.State()) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.loadNotes = { [note1] }
            $0.persistence.loadTags = { [] }
            $0.persistence.cleanupOrphanedAudio = {
                cleanupCalled.setValue(true)
                return 0
            }
        }
        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.tagsLoaded)
        await store.receive(\.notesLoaded) {
            $0.isLoading = false
            $0.notes = [note1]
            $0.recomputeFilteredNotes()
        }
        #expect(cleanupCalled.value == true)
    }

    @Test func onAppearSkipsIfAlreadyLoaded() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }
        await store.send(.onAppear)
    }

    @Test func loadFailureSetsError() async {
        let store = TestStore(initialState: NotesListFeature.State()) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.loadNotes = { throw NSError(domain: "test", code: 1) }
            $0.persistence.loadTags = { [] }
        }
        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.notesLoadFailed) {
            $0.isLoading = false
            $0.loadError = "We couldn't load your notes. Pull down to try again."
        }
    }

    @Test func deleteNote() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { _ in }
        }
        await store.send(.deleteNote(note1))
        await store.receive(\.deleteNoteSucceeded) {
            $0.notes = [note2]
            $0.recomputeFilteredNotes()
        }
    }

    @Test func deleteNoteFailureSetsOperationError() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.deleteNote(note1))
        await store.receive(\.deleteNoteFailed) {
            $0.operationError = "We couldn't delete that note. Please try again."
        }
    }

    @Test func dismissOperationErrorClearsError() async {
        var state = NotesListFeature.State()
        state.operationError = "Some error"
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }
        await store.send(.dismissOperationError) {
            $0.operationError = nil
        }
    }

    @Test func toggleFavorite() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.toggleFavorite(note1)) {
            $0.notes[id: note1.id]?.isFavorite = true
            $0.recomputeFilteredNotes()
        }
    }

    @Test func toggleFavoriteFailedRevertsState() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.toggleFavorite(note1)) {
            $0.notes[id: note1.id]?.isFavorite = true
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.toggleFavoriteFailed) {
            $0.notes[id: note1.id]?.isFavorite = false
            $0.recomputeFilteredNotes()
            $0.operationError = "We couldn't update that note. Please try again."
        }
    }

    @Test func searchDebouncesBeforeFiltering() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        let clock = TestClock()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        await store.send(.binding(.set(\.searchText, "meeting"))) {
            $0.searchText = "meeting"
        }
        // filteredNotes still shows all notes (debouncedSearchText is still "")
        #expect(store.state.filteredNotes.count == 2)

        await clock.advance(by: .milliseconds(300))
        await store.receive(\.searchDebounced) {
            $0.debouncedSearchText = "meeting"
            $0.recomputeFilteredNotes()
        }
        // Now filteredNotes is filtered
        #expect(store.state.filteredNotes.count == 1)
        #expect(store.state.filteredNotes.first?.id == note1.id)
    }

    @Test func searchDebounceCancelsOnNewInput() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        let clock = TestClock()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.continuousClock = clock
        }
        await store.send(.binding(.set(\.searchText, "meet"))) {
            $0.searchText = "meet"
        }
        await clock.advance(by: .milliseconds(200))
        // Type more before debounce fires
        await store.send(.binding(.set(\.searchText, "meeting"))) {
            $0.searchText = "meeting"
        }
        await clock.advance(by: .milliseconds(300))
        // Only the latest value fires
        await store.receive(\.searchDebounced) {
            $0.debouncedSearchText = "meeting"
            $0.recomputeFilteredNotes()
        }
    }

    @Test func filteredNotesMatchesDebouncedSearchText() {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]

        state.debouncedSearchText = "meeting"
        state.recomputeFilteredNotes()
        #expect(state.filteredNotes.count == 1)
        #expect(state.filteredNotes.first?.id == note1.id)

        state.debouncedSearchText = ""
        state.recomputeFilteredNotes()
        #expect(state.filteredNotes.count == 2)
    }

    @Test func filteredNotesSearchesTranscription() {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]

        state.debouncedSearchText = "timeline"
        state.recomputeFilteredNotes()
        #expect(state.filteredNotes.count == 1)
        #expect(state.filteredNotes.first?.id == note1.id)
    }

    // MARK: - Edit Mode

    @Test func editButtonTogglesEditMode() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }

        await store.send(.editButtonTapped) {
            $0.isEditing = true
        }
        await store.send(.editButtonTapped) {
            $0.isEditing = false
        }
    }

    @Test func editModeClearsSelectionOnExit() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id]
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }

        await store.send(.editButtonTapped) {
            $0.isEditing = false
            $0.selectedNoteIDs = []
        }
    }

    @Test func selectAndDeselectNote() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }

        await store.send(.selectNote(note1.id)) {
            $0.selectedNoteIDs = [note1.id]
        }
        await store.send(.selectNote(note2.id)) {
            $0.selectedNoteIDs = [note1.id, note2.id]
        }
        await store.send(.deselectNote(note1.id)) {
            $0.selectedNoteIDs = [note2.id]
        }
    }

    @Test func selectAllAndDeselectAll() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }

        await store.send(.selectAll) {
            $0.selectedNoteIDs = [note1.id, note2.id]
        }
        await store.send(.deselectAll) {
            $0.selectedNoteIDs = []
        }
    }

    // MARK: - Bulk Delete

    @Test func deleteSelectedSuccess() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id]
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { _ in }
        }

        await store.send(.deleteSelectedTapped) {
            $0.showDeleteSelectedConfirmation = true
        }
        await store.send(.confirmDeleteSelected) {
            $0.showDeleteSelectedConfirmation = false
        }
        await store.receive(\.deleteSelectedSucceeded) {
            $0.notes = [note2]
            $0.selectedNoteIDs = []
            $0.isEditing = false
            $0.recomputeFilteredNotes()
        }
    }

    @Test func deleteSelectedAllFail() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id]
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { _ in throw NSError(domain: "test", code: 1) }
        }

        await store.send(.confirmDeleteSelected)
        // Per-item handling: empty success sent first, then failure
        await store.receive(\.deleteSelectedSucceeded) {
            $0.selectedNoteIDs = []
            $0.isEditing = false
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.deleteSelectedFailed) {
            $0.operationError = "1 note(s) couldn't be deleted. Please try again."
        }
    }

    @Test func deleteSelectedPartialFailure() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id, note2.id]
        // Only note2 fails to delete
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { note in
                if note.id == note2.id { throw NSError(domain: "test", code: 1) }
            }
        }

        await store.send(.confirmDeleteSelected)
        // note1 deleted successfully, note2 failed
        await store.receive(\.deleteSelectedSucceeded) {
            $0.notes.remove(id: note1.id)
            $0.selectedNoteIDs = []
            $0.isEditing = false
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.deleteSelectedFailed) {
            $0.operationError = "1 note(s) couldn't be deleted. Please try again."
        }
    }

    @Test func cancelDeleteSelected() async {
        var state = NotesListFeature.State()
        state.showDeleteSelectedConfirmation = true
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }
        await store.send(.cancelDeleteSelected) {
            $0.showDeleteSelectedConfirmation = false
        }
    }

    // MARK: - Delete All

    @Test func deleteAllSuccess() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id]
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { _ in }
        }

        await store.send(.deleteAllTapped) {
            $0.showDeleteAllConfirmation = true
        }
        await store.send(.confirmDeleteAll) {
            $0.showDeleteAllConfirmation = false
        }
        await store.receive(\.deleteAllSucceeded) {
            $0.notes = []
            $0.selectedNoteIDs = []
            $0.isEditing = false
            $0.recomputeFilteredNotes()
        }
    }

    @Test func deleteAllFailure() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { _ in throw NSError(domain: "test", code: 1) }
        }

        await store.send(.confirmDeleteAll)
        await store.receive(\.deleteAllFailed) {
            $0.operationError = "1 note(s) couldn't be deleted. Please try again."
        }
    }

    @Test func deleteAllPartialFailure() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        // Only note2 fails to delete
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.deleteNote = { note in
                if note.id == note2.id { throw NSError(domain: "test", code: 1) }
            }
        }

        await store.send(.confirmDeleteAll)
        // Partial: note1 deleted via deleteSelectedSucceeded, then deleteAllFailed
        await store.receive(\.deleteSelectedSucceeded) {
            $0.notes.remove(id: note1.id)
            $0.selectedNoteIDs = []
            $0.isEditing = false
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.deleteAllFailed) {
            $0.operationError = "1 note(s) couldn't be deleted. Please try again."
        }
    }

    // MARK: - Rename

    @Test func renameFlowSuccess() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }

        await store.send(.renameNoteTapped(note1)) {
            $0.renamingNoteID = note1.id
            $0.renameText = "Meeting notes"
        }

        await store.send(.binding(.set(\.renameText, "Renamed title"))) {
            $0.renameText = "Renamed title"
        }
        await store.send(.confirmRename) {
            $0.notes[id: note1.id]?.title = "Renamed title"
            $0.recomputeFilteredNotes()
            $0.renamingNoteID = nil
            $0.renameText = ""
        }
        await store.receive(\.renameSucceeded)
    }

    @Test func renameFlowFailureReverts() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in throw NSError(domain: "test", code: 1) }
        }

        await store.send(.renameNoteTapped(note1)) {
            $0.renamingNoteID = note1.id
            $0.renameText = "Meeting notes"
        }

        await store.send(.binding(.set(\.renameText, "New title"))) {
            $0.renameText = "New title"
        }
        await store.send(.confirmRename) {
            $0.notes[id: note1.id]?.title = "New title"
            $0.recomputeFilteredNotes()
            $0.renamingNoteID = nil
            $0.renameText = ""
        }
        await store.receive(\.renameFailed) {
            $0.notes[id: note1.id] = note1
            $0.recomputeFilteredNotes()
            $0.operationError = "We couldn't rename that note. Please try again."
        }
    }

    @Test func cancelRename() async {
        var state = NotesListFeature.State()
        state.renamingNoteID = note1.id
        state.renameText = "Some text"
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }
        await store.send(.cancelRename) {
            $0.renamingNoteID = nil
            $0.renameText = ""
        }
    }

    // MARK: - Lock

    @Test func toggleLock() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.isPro = true
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.toggleLock(note1)) {
            $0.notes[id: note1.id]?.isLocked = true
            $0.recomputeFilteredNotes()
        }
    }

    @Test func toggleLockFailedRevertsState() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.isPro = true
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in throw NSError(domain: "test", code: 1) }
        }
        await store.send(.toggleLock(note1)) {
            $0.notes[id: note1.id]?.isLocked = true
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.toggleLockFailed) {
            $0.notes[id: note1.id]?.isLocked = false
            $0.recomputeFilteredNotes()
            $0.operationError = "We couldn't update that note. Please try again."
        }
    }

    @Test func lockSelected() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.isPro = true
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id, note2.id]
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.lockSelected) {
            $0.notes[id: note1.id]?.isLocked = true
            $0.notes[id: note2.id]?.isLocked = true
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.lockSelectedSucceeded)
    }

    @Test func unlockSelected() async {
        var lockedNote1 = note1
        lockedNote1.isLocked = true
        var lockedNote2 = note2
        lockedNote2.isLocked = true

        var state = NotesListFeature.State()
        state.notes = [lockedNote1, lockedNote2]
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id, note2.id]
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        await store.send(.unlockSelected) {
            $0.notes[id: note1.id]?.isLocked = false
            $0.notes[id: note2.id]?.isLocked = false
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.lockSelectedSucceeded)
    }

    @Test func lockSelectedPartialFailure() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.isPro = true
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id, note2.id]
        // note2 fails to persist
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { note in
                if note.id == note2.id { throw NSError(domain: "test", code: 1) }
            }
        }
        await store.send(.lockSelected) {
            $0.notes[id: note1.id]?.isLocked = true
            $0.notes[id: note2.id]?.isLocked = true
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.lockSelectedFailed) {
            // Rollback note2 (the one that failed to persist)
            $0.notes[id: note2.id]?.isLocked = false
            $0.recomputeFilteredNotes()
            $0.operationError = "Failed to lock 1 note(s)."
        }
    }

    @Test func lockSelectedSkipsAlreadyLocked() async {
        var lockedNote1 = note1
        lockedNote1.isLocked = true

        var state = NotesListFeature.State()
        state.notes = [lockedNote1, note2]
        state.isPro = true
        state.recomputeFilteredNotes()
        state.isEditing = true
        state.selectedNoteIDs = [note1.id, note2.id]
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }
        // Only note2 changes since note1 is already locked
        await store.send(.lockSelected) {
            $0.notes[id: note2.id]?.isLocked = true
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.lockSelectedSucceeded)
    }

    // MARK: - Tag Filter

    @Test func tagFilterNarrowsResults() {
        let tagID = UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!
        var taggedNote = note1
        taggedNote.tagIDs = [tagID]

        var state = NotesListFeature.State()
        state.notes = [taggedNote, note2]
        state.allTags = [Tag(id: tagID, name: "Work", color: .blue)]

        state.selectedFilterTagIDs = [tagID]
        state.recomputeFilteredNotes()
        #expect(state.filteredNotes.count == 1)
        #expect(state.filteredNotes.first?.id == note1.id)
    }

    @Test func tagFilterCombinesWithSearch() {
        let tagID = UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!
        var taggedNote1 = note1
        taggedNote1.tagIDs = [tagID]
        var taggedNote2 = note2
        taggedNote2.tagIDs = [tagID]

        var state = NotesListFeature.State()
        state.notes = [taggedNote1, taggedNote2]
        state.allTags = [Tag(id: tagID, name: "Work", color: .blue)]

        state.selectedFilterTagIDs = [tagID]
        state.debouncedSearchText = "Meeting"
        state.recomputeFilteredNotes()
        #expect(state.filteredNotes.count == 1)
        #expect(state.filteredNotes.first?.id == note1.id)
    }

    @Test func toggleFilterTag() async {
        let tagID = UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!
        var taggedNote = note1
        taggedNote.tagIDs = [tagID]

        var state = NotesListFeature.State()
        state.notes = [taggedNote, note2]
        state.allTags = [Tag(id: tagID, name: "Work", color: .blue)]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }

        await store.send(.toggleFilterTag(tagID)) {
            $0.selectedFilterTagIDs = [tagID]
            $0.recomputeFilteredNotes()
        }
        #expect(store.state.filteredNotes.count == 1)

        await store.send(.toggleFilterTag(tagID)) {
            $0.selectedFilterTagIDs = []
            $0.recomputeFilteredNotes()
        }
        #expect(store.state.filteredNotes.count == 2)
    }

    // MARK: - Tag Toggle on Note

    @Test func toggleTagOnNote() async {
        let tagID = UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.allTags = [Tag(id: tagID, name: "Work", color: .blue)]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.updateNote = { _ in }
        }

        await store.send(.toggleTagOnNote(tagID, note1.id)) {
            $0.notes[id: note1.id]?.tagIDs = [tagID]
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.tagAssignmentSucceeded)

        // Toggle again to remove
        await store.send(.toggleTagOnNote(tagID, note1.id)) {
            $0.notes[id: note1.id]?.tagIDs = []
            $0.recomputeFilteredNotes()
        }
        await store.receive(\.tagAssignmentSucceeded)
    }

    // MARK: - Tags loaded during onAppear

    @Test func onAppearLoadsTags() async {
        let tag = Tag(
            id: UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!,
            name: "Work",
            color: .blue
        )
        let store = TestStore(initialState: NotesListFeature.State()) {
            NotesListFeature()
        } withDependencies: {
            $0.persistence.loadNotes = { [note1] }
            $0.persistence.loadTags = { [tag] }
            $0.persistence.cleanupOrphanedAudio = { 0 }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.tagsLoaded) {
            $0.allTags = [tag]
        }
        await store.receive(\.notesLoaded) {
            $0.isLoading = false
            $0.notes = [note1]
            $0.recomputeFilteredNotes()
        }
    }

    // MARK: - Subscription Gates

    @Test func createTagFreeUserAtLimitShowsPaywall() async {
        let tag1 = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!, name: "Work", color: .blue)
        let tag2 = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-bbbbbbbbbbbb")!, name: "Personal", color: .green)
        let tag3 = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-cccccccccccc")!, name: "Urgent", color: .red)

        var state = NotesListFeature.State()
        state.notes = [note1]
        state.allTags = [tag1, tag2, tag3]
        state.isPro = false
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }
        await store.send(.createTagTapped)
        await store.receive(\.delegate.paywallRequested)
    }

    @Test func createTagProUserAllowed() async {
        let tag1 = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-aaaaaaaaaaaa")!, name: "Work", color: .blue)
        let tag2 = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-bbbbbbbbbbbb")!, name: "Personal", color: .green)
        let tag3 = Tag(id: UUID(uuidString: "00000000-0000-0000-0000-cccccccccccc")!, name: "Urgent", color: .red)

        var state = NotesListFeature.State()
        state.notes = [note1]
        state.allTags = [tag1, tag2, tag3]
        state.isPro = true
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }
        // TagEditorFeature.State() generates a random UUID, so use non-exhaustive
        // to verify the gate passes without matching the exact UUID
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.createTagTapped)
        #expect(store.state.tagEditor != nil)
        #expect(store.state.tagEditor?.isNew == true)
    }

    @Test func toggleLockFreeUserShowsPaywall() async {
        var state = NotesListFeature.State()
        state.notes = [note1]
        state.isPro = false
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }
        await store.send(.toggleLock(note1))
        await store.receive(\.delegate.paywallRequested)
    }

    @Test func lockSelectedFreeUserShowsPaywall() async {
        var state = NotesListFeature.State()
        state.notes = [note1, note2]
        state.isPro = false
        state.isEditing = true
        state.selectedNoteIDs = [note1.id]
        state.recomputeFilteredNotes()
        let store = TestStore(initialState: state) {
            NotesListFeature()
        }
        await store.send(.lockSelected)
        await store.receive(\.delegate.paywallRequested)
    }
}
