import ComposableArchitecture
import DXWhispKit
import Foundation

@Reducer
public struct NotesListFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var notes: IdentifiedArrayOf<VoiceNote> = []
        public var isLoading: Bool = false
        public var loadError: String?
        public var operationError: String?
        public var searchText: String = ""
        public var debouncedSearchText: String = ""

        // Edit mode
        public var isEditing: Bool = false
        public var selectedNoteIDs: Set<UUID> = []

        // Tags
        public var allTags: IdentifiedArrayOf<Tag> = []
        public var selectedFilterTagIDs: Set<UUID> = []

        // Rename
        public var renamingNoteID: UUID?
        public var renameText: String = ""

        // Confirmation dialogs
        public var showDeleteSelectedConfirmation: Bool = false
        public var showDeleteAllConfirmation: Bool = false

        // Tag editor
        @Presents public var tagEditor: TagEditorFeature.State?

        /// Memoized filtered notes — recomputed by the reducer on data/search changes.
        public private(set) var filteredNotes: [VoiceNote] = []
        /// Memoized favorite/non-favorite split — avoids O(2n) filter in view body.
        public private(set) var filteredFavorites: [VoiceNote] = []
        public private(set) var filteredOthers: [VoiceNote] = []

        public var isPro: Bool = false

        public init() {}

        /// Recomputes `filteredNotes`, `filteredFavorites`, and `filteredOthers` from current
        /// `notes`, `selectedFilterTagIDs`, and `debouncedSearchText`.
        /// Call this from the reducer after any mutation to `notes`, `selectedFilterTagIDs`, or `debouncedSearchText`.
        public mutating func recomputeFilteredNotes() {
            var result = notes.elements

            // Apply tag filter
            if !selectedFilterTagIDs.isEmpty {
                result = result.filter { note in
                    !selectedFilterTagIDs.isDisjoint(with: note.tagIDs)
                }
            }

            // Apply text search
            if !debouncedSearchText.isEmpty {
                result = result.filter { note in
                    note.title.localizedCaseInsensitiveContains(debouncedSearchText) ||
                        note.transcription?.text.localizedCaseInsensitiveContains(debouncedSearchText) == true
                }
            }

            filteredNotes = result
            filteredFavorites = result.filter(\.isFavorite)
            filteredOthers = result.filter { !$0.isFavorite }
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case onAppear
        case notesLoaded([VoiceNote])
        case notesLoadFailed(String)
        case noteTapped(VoiceNote)
        case deleteNote(VoiceNote)
        case deleteNoteSucceeded(UUID)
        case deleteNoteFailed(String)
        case dismissOperationError
        case toggleFavorite(VoiceNote)
        case toggleFavoriteFailed(VoiceNote)
        case toggleLock(VoiceNote)
        case toggleLockFailed(VoiceNote)
        case lockSelected
        case unlockSelected
        case lockSelectedSucceeded
        case lockSelectedFailed(String, [VoiceNote])
        case searchDebounced(String)
        case noteUpdated(VoiceNote)
        case delegate(Delegate)

        // Edit mode
        case editButtonTapped
        case selectNote(UUID)
        case deselectNote(UUID)
        case selectAll
        case deselectAll

        // Bulk delete
        case deleteSelectedTapped
        case confirmDeleteSelected
        case cancelDeleteSelected
        case deleteSelectedSucceeded(Set<UUID>)
        case deleteSelectedFailed(String)

        // Delete all
        case deleteAllTapped
        case confirmDeleteAll
        case cancelDeleteAll
        case deleteAllSucceeded
        case deleteAllFailed(String)

        // Rename
        case renameNoteTapped(VoiceNote)
        case confirmRename
        case cancelRename
        case renameSucceeded(VoiceNote)
        case renameFailed(VoiceNote, String)

        // Tags
        case tagsLoaded([Tag])
        case toggleFilterTag(UUID)
        case clearTagFilter
        case toggleTagOnNote(Tag.ID, VoiceNote.ID)
        case toggleTagOnSelected(Tag.ID)
        case tagAssignmentSucceeded
        case tagAssignmentFailed(String, [VoiceNote])

        // Tag management
        case createTagTapped
        case editTagTapped(Tag)
        case deleteTagTapped(Tag)
        case tagEditor(PresentationAction<TagEditorFeature.Action>)
        case tagSaveSucceeded
        case tagSaveFailed(String)
        case tagDeleteFailed([Tag], [VoiceNote], Set<UUID>)

        @CasePathable
        public enum Delegate: Sendable {
            case paywallRequested
        }
    }

    @Dependency(\.persistence) var persistence
    @Dependency(\.continuousClock) var clock
    @Dependency(\.haptic) var haptic

    private enum CancelID { case search }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.searchText):
                return .run { [searchText = state.searchText] send in
                    try await clock.sleep(for: .milliseconds(300))
                    await send(.searchDebounced(searchText))
                }
                .cancellable(id: CancelID.search, cancelInFlight: true)

            case .binding:
                return .none

            case let .searchDebounced(text):
                state.debouncedSearchText = text
                state.recomputeFilteredNotes()
                return .none

            case .onAppear:
                // Only load if we haven't loaded yet
                guard state.notes.isEmpty, !state.isLoading else { return .none }
                state.isLoading = true
                state.loadError = nil
                return .run { send in
                    do {
                        async let notesResult = persistence.loadNotes()
                        async let tagsResult = persistence.loadTags()
                        let notes = try await notesResult
                        let tags = try await tagsResult
                        await send(.tagsLoaded(tags))
                        await send(.notesLoaded(notes))
                    } catch {
                        await send(.notesLoadFailed(L10n.NotesList.loadFailed))
                    }
                }

            case let .notesLoaded(notes):
                state.isLoading = false
                state.loadError = nil
                let loadedIds = Set(notes.map(\.id))
                let onlyInState = state.notes.elements.filter { !loadedIds.contains($0.id) }
                let merged = (notes + onlyInState).sorted { $0.createdAt > $1.createdAt }
                state.notes = IdentifiedArray(uniqueElements: merged)
                state.recomputeFilteredNotes()
                // Fire-and-forget: clean up orphaned audio files (non-state-affecting)
                return .run { _ in
                    _ = await persistence.cleanupOrphanedAudio()
                }

            case let .notesLoadFailed(message):
                state.isLoading = false
                state.loadError = message
                return .none

            case .noteTapped:
                return .none

            case let .deleteNote(note):
                return .run { send in
                    do {
                        try await persistence.deleteNote(note)
                        await send(.deleteNoteSucceeded(note.id))
                    } catch {
                        await send(.deleteNoteFailed(L10n.NotesList.deleteFailed))
                    }
                }

            case let .deleteNoteFailed(message):
                state.operationError = message
                return .none

            case .dismissOperationError:
                state.operationError = nil
                return .none

            case let .deleteNoteSucceeded(id):
                state.notes.remove(id: id)
                state.selectedNoteIDs.remove(id)
                state.recomputeFilteredNotes()
                return .none

            case let .toggleFavorite(note):
                state.notes[id: note.id]?.isFavorite.toggle()
                state.recomputeFilteredNotes()
                guard let updatedNote = state.notes[id: note.id] else { return .none }
                return .run { send in
                    do {
                        try await persistence.updateNote(updatedNote)
                    } catch {
                        await send(.toggleFavoriteFailed(note))
                    }
                }

            case let .toggleFavoriteFailed(originalNote):
                state.notes[id: originalNote.id] = originalNote
                state.recomputeFilteredNotes()
                state.operationError = L10n.NotesList.updateFailed
                return .none

            // MARK: - Lock

            case let .toggleLock(note):
                // Free tier: locking requires Pro
                if !state.isPro && !note.isLocked {
                    return .send(.delegate(.paywallRequested))
                }
                state.notes[id: note.id]?.isLocked.toggle()
                state.recomputeFilteredNotes()
                guard let updatedNote = state.notes[id: note.id] else { return .none }
                return .run { send in
                    do {
                        try await persistence.updateNote(updatedNote)
                    } catch {
                        await send(.toggleLockFailed(note))
                    }
                }

            case let .toggleLockFailed(originalNote):
                state.notes[id: originalNote.id] = originalNote
                state.recomputeFilteredNotes()
                state.operationError = L10n.NotesList.updateFailed
                return .none

            case .lockSelected:
                if !state.isPro {
                    return .send(.delegate(.paywallRequested))
                }
                let selectedIDs = state.selectedNoteIDs
                var updatedNotes: [VoiceNote] = []
                var originalNotes: [VoiceNote] = []
                for id in selectedIDs {
                    guard var note = state.notes[id: id], !note.isLocked else { continue }
                    originalNotes.append(note)
                    note.isLocked = true
                    state.notes[id: id] = note
                    updatedNotes.append(note)
                }
                state.recomputeFilteredNotes()
                let notesToPersist = updatedNotes
                let capturedOriginals = originalNotes
                guard !notesToPersist.isEmpty else { return .none }
                return .run { send in
                    var failedIDs: Set<UUID> = []
                    for note in notesToPersist {
                        do {
                            try await persistence.updateNote(note)
                        } catch {
                            failedIDs.insert(note.id)
                        }
                    }
                    if failedIDs.isEmpty {
                        await send(.lockSelectedSucceeded)
                    } else {
                        let originals = capturedOriginals.filter { failedIDs.contains($0.id) }
                        await send(.lockSelectedFailed(L10n.NotesList.lockFailed(failedIDs.count), originals))
                    }
                }

            case .unlockSelected:
                let selectedIDs = state.selectedNoteIDs
                var updatedNotes: [VoiceNote] = []
                var originalNotes: [VoiceNote] = []
                for id in selectedIDs {
                    guard var note = state.notes[id: id], note.isLocked else { continue }
                    originalNotes.append(note)
                    note.isLocked = false
                    state.notes[id: id] = note
                    updatedNotes.append(note)
                }
                state.recomputeFilteredNotes()
                let notesToPersist = updatedNotes
                let capturedOriginals = originalNotes
                guard !notesToPersist.isEmpty else { return .none }
                return .run { send in
                    var failedIDs: Set<UUID> = []
                    for note in notesToPersist {
                        do {
                            try await persistence.updateNote(note)
                        } catch {
                            failedIDs.insert(note.id)
                        }
                    }
                    if failedIDs.isEmpty {
                        await send(.lockSelectedSucceeded)
                    } else {
                        let originals = capturedOriginals.filter { failedIDs.contains($0.id) }
                        await send(.lockSelectedFailed(L10n.NotesList.unlockFailed(failedIDs.count), originals))
                    }
                }

            case .lockSelectedSucceeded:
                return .none

            case let .lockSelectedFailed(message, failedOriginals):
                for original in failedOriginals {
                    state.notes[id: original.id] = original
                }
                state.recomputeFilteredNotes()
                state.operationError = message
                return .none

            case let .noteUpdated(note):
                state.notes[id: note.id] = note
                state.recomputeFilteredNotes()
                return .none

            // MARK: - Edit Mode

            case .editButtonTapped:
                state.isEditing.toggle()
                if !state.isEditing {
                    state.selectedNoteIDs.removeAll()
                }
                return .run { @MainActor [isEditing = state.isEditing] _ in
                    if isEditing {
                        haptic.impact(.medium)
                    }
                }

            case let .selectNote(id):
                state.selectedNoteIDs.insert(id)
                return .run { @MainActor _ in haptic.selection() }

            case let .deselectNote(id):
                state.selectedNoteIDs.remove(id)
                return .none

            case .selectAll:
                state.selectedNoteIDs = Set(state.filteredNotes.map(\.id))
                return .run { @MainActor _ in haptic.impact(.light) }

            case .deselectAll:
                state.selectedNoteIDs.removeAll()
                return .none

            // MARK: - Bulk Delete

            case .deleteSelectedTapped:
                guard !state.selectedNoteIDs.isEmpty else { return .none }
                state.showDeleteSelectedConfirmation = true
                return .none

            case .cancelDeleteSelected:
                state.showDeleteSelectedConfirmation = false
                return .none

            case .confirmDeleteSelected:
                state.showDeleteSelectedConfirmation = false
                let idsToDelete = state.selectedNoteIDs
                let notesToDelete = state.notes.elements.filter { idsToDelete.contains($0.id) }
                return .run { send in
                    var deletedIDs: Set<UUID> = []
                    for note in notesToDelete {
                        do {
                            try await persistence.deleteNote(note)
                            deletedIDs.insert(note.id)
                        } catch {
                            // Continue — partial success still removes what we can
                        }
                    }
                    await send(.deleteSelectedSucceeded(deletedIDs))
                    if deletedIDs.count < notesToDelete.count {
                        let failedCount = notesToDelete.count - deletedIDs.count
                        await send(.deleteSelectedFailed(L10n.NotesList.bulkDeleteFailed(failedCount)))
                    }
                }

            case let .deleteSelectedSucceeded(ids):
                for id in ids {
                    state.notes.remove(id: id)
                }
                state.selectedNoteIDs.removeAll()
                state.isEditing = false
                state.recomputeFilteredNotes()
                return .run { @MainActor _ in haptic.notification(.success) }

            case let .deleteSelectedFailed(message):
                state.operationError = message
                return .run { @MainActor _ in haptic.notification(.error) }

            // MARK: - Delete All

            case .deleteAllTapped:
                state.showDeleteAllConfirmation = true
                return .none

            case .cancelDeleteAll:
                state.showDeleteAllConfirmation = false
                return .none

            case .confirmDeleteAll:
                state.showDeleteAllConfirmation = false
                let allNotes = state.notes.elements
                return .run { send in
                    var deletedIDs: Set<UUID> = []
                    for note in allNotes {
                        do {
                            try await persistence.deleteNote(note)
                            deletedIDs.insert(note.id)
                        } catch {
                            // Continue — partial success still removes what we can
                        }
                    }
                    if deletedIDs.count == allNotes.count {
                        await send(.deleteAllSucceeded)
                    } else {
                        if !deletedIDs.isEmpty {
                            await send(.deleteSelectedSucceeded(deletedIDs))
                        }
                        let failedCount = allNotes.count - deletedIDs.count
                        await send(.deleteAllFailed(L10n.NotesList.bulkDeleteFailed(failedCount)))
                    }
                }

            case .deleteAllSucceeded:
                state.notes.removeAll()
                state.selectedNoteIDs.removeAll()
                state.isEditing = false
                state.recomputeFilteredNotes()
                return .run { @MainActor _ in haptic.notification(.success) }

            case let .deleteAllFailed(message):
                state.operationError = message
                return .run { @MainActor _ in haptic.notification(.error) }

            // MARK: - Rename

            case let .renameNoteTapped(note):
                state.renamingNoteID = note.id
                state.renameText = note.title
                return .none

            case .confirmRename:
                guard let noteID = state.renamingNoteID else { return .none }
                let trimmed = state.renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, var note = state.notes[id: noteID] else {
                    state.renamingNoteID = nil
                    state.renameText = ""
                    return .none
                }
                let originalNote = note
                note.title = trimmed
                state.notes[id: noteID] = note
                state.recomputeFilteredNotes()
                state.renamingNoteID = nil
                state.renameText = ""
                return .run { [updatedNote = note] send in
                    do {
                        try await persistence.updateNote(updatedNote)
                        await send(.renameSucceeded(updatedNote))
                    } catch {
                        await send(.renameFailed(originalNote, L10n.NotesList.renameFailed))
                    }
                }

            case .cancelRename:
                state.renamingNoteID = nil
                state.renameText = ""
                return .none

            case .renameSucceeded:
                return .none

            case let .renameFailed(originalNote, message):
                state.notes[id: originalNote.id] = originalNote
                state.recomputeFilteredNotes()
                state.operationError = message
                return .none

            // MARK: - Tags

            case let .tagsLoaded(tags):
                state.allTags = IdentifiedArray(uniqueElements: tags)
                return .none

            case let .toggleFilterTag(tagID):
                if state.selectedFilterTagIDs.contains(tagID) {
                    state.selectedFilterTagIDs.remove(tagID)
                } else {
                    state.selectedFilterTagIDs.insert(tagID)
                }
                state.recomputeFilteredNotes()
                return .none

            case .clearTagFilter:
                state.selectedFilterTagIDs.removeAll()
                state.recomputeFilteredNotes()
                return .none

            case let .toggleTagOnNote(tagID, noteID):
                guard var note = state.notes[id: noteID] else { return .none }
                let originalNote = note
                if let idx = note.tagIDs.firstIndex(of: tagID) {
                    note.tagIDs.remove(at: idx)
                } else {
                    note.tagIDs.append(tagID)
                }
                state.notes[id: noteID] = note
                state.recomputeFilteredNotes()
                return .run { [updatedNote = note] send in
                    do {
                        try await persistence.updateNote(updatedNote)
                        await send(.tagAssignmentSucceeded)
                    } catch {
                        await send(.tagAssignmentFailed(L10n.NotesList.tagUpdateFailed, [originalNote]))
                    }
                }

            case let .toggleTagOnSelected(tagID):
                let selectedIDs = state.selectedNoteIDs
                var updatedNotes: [VoiceNote] = []
                var originalNotes: [VoiceNote] = []
                for id in selectedIDs {
                    guard var note = state.notes[id: id] else { continue }
                    if !note.tagIDs.contains(tagID) {
                        originalNotes.append(note)
                        note.tagIDs.append(tagID)
                        state.notes[id: id] = note
                        updatedNotes.append(note)
                    }
                }
                state.recomputeFilteredNotes()
                let notesToPersist = updatedNotes
                let capturedOriginals = originalNotes
                guard !notesToPersist.isEmpty else { return .none }
                return .run { send in
                    var failedIDs: Set<UUID> = []
                    for note in notesToPersist {
                        do {
                            try await persistence.updateNote(note)
                        } catch {
                            failedIDs.insert(note.id)
                        }
                    }
                    if failedIDs.isEmpty {
                        await send(.tagAssignmentSucceeded)
                    } else {
                        let originals = capturedOriginals.filter { failedIDs.contains($0.id) }
                        await send(.tagAssignmentFailed(L10n.NotesList.tagUpdateFailedCount(failedIDs.count), originals))
                    }
                }

            case .tagAssignmentSucceeded:
                return .none

            case let .tagAssignmentFailed(message, originalNotes):
                for original in originalNotes {
                    state.notes[id: original.id] = original
                }
                state.recomputeFilteredNotes()
                state.operationError = message
                return .none

            // MARK: - Tag Management

            case .createTagTapped:
                // Free tier: 3 tags max
                if !state.isPro && state.allTags.count >= 3 {
                    return .send(.delegate(.paywallRequested))
                }
                state.tagEditor = TagEditorFeature.State()
                return .none

            case let .editTagTapped(tag):
                state.tagEditor = TagEditorFeature.State(tag: tag)
                return .none

            case let .deleteTagTapped(tag):
                // Capture pre-mutation state for rollback
                let originalTags = state.allTags
                let affectedNoteIDs = Set(state.notes.elements.filter { $0.tagIDs.contains(tag.id) }.map(\.id))
                let originalNotes = affectedNoteIDs.compactMap { state.notes[id: $0] }
                let originalFilterTagIDs = state.selectedFilterTagIDs
                // Optimistic mutation
                state.allTags.remove(id: tag.id)
                for id in affectedNoteIDs {
                    state.notes[id: id]?.tagIDs.removeAll { $0 == tag.id }
                }
                state.selectedFilterTagIDs.remove(tag.id)
                state.recomputeFilteredNotes()
                let tags = state.allTags.elements
                let notesToUpdate = affectedNoteIDs.compactMap { state.notes[id: $0] }
                return .run { send in
                    try await persistence.saveTags(tags)
                    var noteUpdateFailures = 0
                    for note in notesToUpdate {
                        do {
                            try await persistence.updateNote(note)
                        } catch {
                            noteUpdateFailures += 1
                        }
                    }
                    await send(.tagSaveSucceeded)
                    if noteUpdateFailures > 0 {
                        await send(.tagSaveFailed(L10n.NotesList.tagUpdateFailedCount(noteUpdateFailures)))
                    }
                } catch: { [originalTags, originalNotes, originalFilterTagIDs] _, send in
                    await send(.tagDeleteFailed(originalTags.elements, originalNotes, originalFilterTagIDs))
                }

            case let .tagEditor(.presented(.delegate(.tagSaved(tag)))):
                if state.allTags[id: tag.id] != nil {
                    state.allTags[id: tag.id] = tag
                } else {
                    state.allTags.append(tag)
                }
                state.tagEditor = nil
                let tags = state.allTags.elements
                return .run { send in
                    try await persistence.saveTags(tags)
                    await send(.tagSaveSucceeded)
                } catch: { _, send in
                    await send(.tagSaveFailed(L10n.NotesList.tagSaveFailed))
                }

            case .tagEditor(.presented(.cancelTapped)):
                state.tagEditor = nil
                return .none

            case .tagEditor:
                return .none

            case .tagSaveSucceeded:
                return .none

            case let .tagSaveFailed(message):
                state.operationError = message
                return .none

            case let .tagDeleteFailed(originalTags, originalNotes, originalFilterTagIDs):
                state.allTags = IdentifiedArray(uniqueElements: originalTags)
                for note in originalNotes {
                    state.notes[id: note.id] = note
                }
                state.selectedFilterTagIDs = originalFilterTagIDs
                state.recomputeFilteredNotes()
                state.operationError = L10n.NotesList.tagDeleteFailed
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$tagEditor, action: \.tagEditor) {
            TagEditorFeature()
        }
    }
}
