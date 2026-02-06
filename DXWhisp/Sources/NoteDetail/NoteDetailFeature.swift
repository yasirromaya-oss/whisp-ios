import ComposableArchitecture
import DXWhispKit
import Foundation

@Reducer
public struct NoteDetailFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var note: VoiceNote
        public var isPlaying: Bool = false
        public var playbackSessionActive: Bool = false
        public var playbackProgress: Double = 0
        public var currentTime: TimeInterval = 0
        public var showDeleteConfirmation: Bool = false
        public var errorMessage: String?
        public var isAuthenticated: Bool = false
        public var isEditingTranscript: Bool = false
        public var editedTranscriptText: String = ""
        public var isReExtractingInsights: Bool = false

        public init(note: VoiceNote) {
            self.note = note
            // Unlocked notes are considered authenticated by default
            self.isAuthenticated = !note.isLocked
        }
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case playPauseTapped
        case seek(Double)
        case playbackTimerTicked
        case playbackProgressUpdated(currentTime: TimeInterval, progress: Double)
        case playbackFinished
        case playbackFailed(String)
        case deleteButtonTapped
        case confirmDelete
        case toggleActionItemCompleted(ActionItem.ID)
        case toggleActionItemFailed(ActionItem)
        case exportToReminders(ActionItem)
        case exportToCalendar(ExtractedEvent)
        case exportToRemindersFailed(ActionItem)
        case exportToCalendarFailed(ExtractedEvent)
        case deleteFailed
        case toggleFavoriteFailed
        case dismissError
        case toggleFavorite
        case authenticationRequired
        case authenticationSucceeded
        case authenticationFailed(String)
        case toggleLock
        case toggleLockFailed
        case editTranscriptTapped
        case cancelEditTranscript
        case saveTranscript
        case saveTranscriptPersistFailed(String)
        case reExtractInsightsCompleted(Insights)
        case reExtractInsightsFailed(String)
        case reExtractInsightsPersistFailed(String)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable {
            case noteUpdated(VoiceNote)
            case noteDeleted(UUID)
        }
    }

    @Dependency(\.persistence) var persistence
    @Dependency(\.audioPlayer) var audioPlayer
    @Dependency(\.eventKit) var eventKit
    @Dependency(\.continuousClock) var clock
    @Dependency(\.haptic) var haptic
    @Dependency(\.biometric) var biometric
    @Dependency(\.transcription) var transcription

    private enum CancelID { case playbackTimer, playback, insightExtraction, biometricAuth }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .playPauseTapped:
                if state.isPlaying {
                    // Pause — keep the playback session alive for resume
                    state.isPlaying = false
                    return .merge(
                        .run { _ in await audioPlayer.pause() },
                        .cancel(id: CancelID.playbackTimer)
                    )
                } else if state.playbackSessionActive {
                    // Resume existing paused session
                    state.isPlaying = true
                    return .merge(
                        .run { _ in await audioPlayer.resume() },
                        .run { send in
                            for await _ in clock.timer(interval: .milliseconds(100)) {
                                await send(.playbackTimerTicked)
                            }
                        }
                        .cancellable(id: CancelID.playbackTimer, cancelInFlight: true)
                    )
                } else {
                    // Fresh play
                    state.isPlaying = true
                    state.playbackSessionActive = true
                    return .merge(
                        .run { [url = state.note.audioURL] send in
                            do {
                                let finishedStream = try await audioPlayer.play(url)
                                for await _ in finishedStream {
                                    await send(.playbackFinished)
                                }
                            } catch {
                                if !(error is CancellationError) {
                                    await send(.playbackFailed(error.localizedDescription))
                                }
                            }
                            // Clean up audio on task cancellation (e.g., sheet dismiss)
                            if Task.isCancelled {
                                await audioPlayer.pause()
                            }
                        }
                        .cancellable(id: CancelID.playback, cancelInFlight: true),
                        .run { send in
                            for await _ in clock.timer(interval: .milliseconds(100)) {
                                await send(.playbackTimerTicked)
                            }
                        }
                        .cancellable(id: CancelID.playbackTimer, cancelInFlight: true)
                    )
                }

            case let .seek(progress):
                let time = state.note.duration * progress
                state.playbackProgress = progress
                state.currentTime = time
                return .run { _ in
                    await audioPlayer.seek(time)
                }

            case .playbackTimerTicked:
                return .run { [duration = state.note.duration] send in
                    let current = await audioPlayer.currentTime()
                    let progress = duration > 0 ? current / duration : 0
                    await send(.playbackProgressUpdated(currentTime: current, progress: progress))
                }

            case let .playbackProgressUpdated(currentTime, progress):
                state.currentTime = currentTime
                state.playbackProgress = progress
                return .none

            case .playbackFinished:
                state.isPlaying = false
                state.playbackSessionActive = false
                state.playbackProgress = 0
                state.currentTime = 0
                return .cancel(id: CancelID.playbackTimer)

            case let .playbackFailed(message):
                state.isPlaying = false
                state.playbackSessionActive = false
                state.playbackProgress = 0
                state.currentTime = 0
                state.errorMessage = message
                return .cancel(id: CancelID.playbackTimer)

            case let .toggleActionItemCompleted(itemId):
                guard let index = state.note.insights?.actionItems.firstIndex(where: { $0.id == itemId }) else {
                    return .none
                }
                state.note.insights?.actionItems[index].isCompleted.toggle()
                let updatedItem = state.note.insights!.actionItems[index]
                return .run { [note = state.note] send in
                    do {
                        try await persistence.updateNote(note)
                        await send(.delegate(.noteUpdated(note)))
                    } catch {
                        await send(.toggleActionItemFailed(updatedItem))
                    }
                }

            case let .toggleActionItemFailed(item):
                // Revert the toggle
                var revertedItem = item
                revertedItem.isCompleted.toggle()
                updateActionItem(&state.note, revertedItem)
                state.errorMessage = L10n.NoteDetail.saveFailed
                return .none

            case .deleteButtonTapped:
                state.showDeleteConfirmation = true
                return .none

            case .confirmDelete:
                let noteId = state.note.id
                let note = state.note
                return .merge(
                    .run { @MainActor _ in haptic.notification(.warning) },
                    .run { send in
                        do {
                            try await persistence.deleteNote(note)
                            await send(.delegate(.noteDeleted(noteId)))
                        } catch {
                            await send(.deleteFailed)
                        }
                    }
                )

            case .deleteFailed:
                state.errorMessage = L10n.NoteDetail.deleteFailed
                return .none

            case .dismissError:
                state.errorMessage = nil
                return .none

            case var .exportToReminders(item):
                let originalItem = item
                item = ActionItem(
                    id: item.id,
                    text: item.text,
                    isCompleted: item.isCompleted,
                    exportedToReminders: true
                )
                updateActionItem(&state.note, item)
                return .merge(
                    .run { @MainActor _ in haptic.notification(.success) },
                    .run { [note = state.note, text = originalItem.text] send in
                        do {
                            _ = await eventKit.requestRemindersAccess()
                            try await eventKit.addReminder(text, nil)
                            try await persistence.updateNote(note)
                            await send(.delegate(.noteUpdated(note)))
                        } catch {
                            await send(.exportToRemindersFailed(originalItem))
                        }
                    }
                )

            case let .exportToRemindersFailed(originalItem):
                updateActionItem(&state.note, originalItem)
                state.errorMessage = L10n.NoteDetail.exportRemindersFailed
                return .none

            case var .exportToCalendar(event):
                let originalEvent = event
                event = ExtractedEvent(
                    id: event.id,
                    title: event.title,
                    date: event.date,
                    rawDateText: event.rawDateText,
                    exportedToCalendar: true
                )
                updateEvent(&state.note, event)
                return .merge(
                    .run { @MainActor _ in haptic.notification(.success) },
                    .run { [note = state.note] send in
                        do {
                            _ = await eventKit.requestCalendarAccess()
                            let date = originalEvent.date ?? Date()
                            try await eventKit.addCalendarEvent(originalEvent.title, date, nil)
                            try await persistence.updateNote(note)
                            await send(.delegate(.noteUpdated(note)))
                        } catch {
                            await send(.exportToCalendarFailed(originalEvent))
                        }
                    }
                )

            case let .exportToCalendarFailed(originalEvent):
                updateEvent(&state.note, originalEvent)
                state.errorMessage = L10n.NoteDetail.exportCalendarFailed
                return .none

            case .toggleFavorite:
                state.note.isFavorite.toggle()
                return .merge(
                    .run { @MainActor _ in haptic.selection() },
                    .run { [note = state.note] send in
                        do {
                            try await persistence.updateNote(note)
                            await send(.delegate(.noteUpdated(note)))
                        } catch {
                            await send(.toggleFavoriteFailed)
                        }
                    }
                )

            case .toggleFavoriteFailed:
                state.note.isFavorite.toggle()
                state.errorMessage = L10n.NoteDetail.saveFailed
                return .none

            case .authenticationRequired:
                return .run { send in
                    do {
                        let success = try await biometric.authenticate(L10n.App.authenticateToView)
                        if success {
                            await send(.authenticationSucceeded)
                        } else {
                            await send(.authenticationFailed(L10n.NoteDetail.authFailed))
                        }
                    } catch {
                        await send(.authenticationFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.biometricAuth, cancelInFlight: true)

            case .authenticationSucceeded:
                state.isAuthenticated = true
                return .none

            case let .authenticationFailed(message):
                state.isAuthenticated = false
                state.errorMessage = message
                return .none

            case .toggleLock:
                state.note.isLocked.toggle()
                if !state.note.isLocked {
                    state.isAuthenticated = true
                }
                return .run { [note = state.note] send in
                    do {
                        try await persistence.updateNote(note)
                        await send(.delegate(.noteUpdated(note)))
                    } catch {
                        await send(.toggleLockFailed)
                    }
                }

            case .toggleLockFailed:
                state.note.isLocked.toggle()
                if !state.note.isLocked {
                    state.isAuthenticated = true
                }
                state.errorMessage = L10n.NoteDetail.lockFailed
                return .none

            case .editTranscriptTapped:
                guard state.note.transcription != nil else { return .none }
                state.isEditingTranscript = true
                state.editedTranscriptText = state.note.transcription?.text ?? ""
                return .none

            case .cancelEditTranscript:
                state.isEditingTranscript = false
                state.editedTranscriptText = ""
                return .none

            case .saveTranscript:
                let newText = state.editedTranscriptText
                state.note.transcription = Transcription(
                    text: newText,
                    segments: state.note.transcription?.segments ?? [],
                    speakerTurns: state.note.transcription?.speakerTurns ?? []
                )
                state.isEditingTranscript = false
                state.editedTranscriptText = ""
                state.isReExtractingInsights = true
                return .run { [note = state.note] send in
                    do {
                        try await persistence.updateNote(note)
                        await send(.delegate(.noteUpdated(note)))
                    } catch {
                        await send(.saveTranscriptPersistFailed(error.localizedDescription))
                        return
                    }
                    do {
                        let insights = try await transcription.extractInsights(newText)
                        await send(.reExtractInsightsCompleted(insights))
                    } catch {
                        await send(.reExtractInsightsFailed(error.localizedDescription))
                    }
                }
                .cancellable(id: CancelID.insightExtraction, cancelInFlight: true)

            case let .saveTranscriptPersistFailed(message):
                state.isReExtractingInsights = false
                state.errorMessage = L10n.NoteDetail.saveTranscriptFailed(message)
                return .none

            case let .reExtractInsightsCompleted(newInsights):
                state.isReExtractingInsights = false
                state.note.insights = mergeInsights(old: state.note.insights, new: newInsights)
                return .run { [note = state.note] send in
                    do {
                        try await persistence.updateNote(note)
                        await send(.delegate(.noteUpdated(note)))
                    } catch {
                        await send(.reExtractInsightsPersistFailed(error.localizedDescription))
                    }
                }

            case let .reExtractInsightsFailed(message):
                state.isReExtractingInsights = false
                state.errorMessage = L10n.NoteDetail.reExtractFailed(message)
                return .none

            case let .reExtractInsightsPersistFailed(message):
                state.errorMessage = L10n.NoteDetail.saveInsightsFailed(message)
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

private func updateActionItem(_ note: inout VoiceNote, _ item: ActionItem) {
    guard let index = note.insights?.actionItems.firstIndex(where: { $0.id == item.id }) else { return }
    note.insights?.actionItems[index] = item
}

private func updateEvent(_ note: inout VoiceNote, _ event: ExtractedEvent) {
    guard let index = note.insights?.events.firstIndex(where: { $0.id == event.id }) else { return }
    note.insights?.events[index] = event
}

/// Merges new insights with old, preserving user state (completion, export flags).
/// Matches items by text (case-insensitive) to carry over IDs and flags.
/// Unmatched old items that were completed or exported are kept at the end.
private func mergeInsights(old: Insights?, new: Insights) -> Insights {
    guard let old else { return new }

    // Track which old items got matched
    var matchedOldActionIDs = Set<ActionItem.ID>()
    var matchedOldEventIDs = Set<ExtractedEvent.ID>()

    // Merge action items: preserve isCompleted, exportedToReminders, id
    let mergedActionItems = new.actionItems.map { newItem -> ActionItem in
        if let match = old.actionItems.first(where: {
            $0.text.localizedCaseInsensitiveCompare(newItem.text) == .orderedSame
        }) {
            matchedOldActionIDs.insert(match.id)
            return ActionItem(
                id: match.id,
                text: newItem.text,
                isCompleted: match.isCompleted,
                exportedToReminders: match.exportedToReminders
            )
        }
        return newItem
    }

    // Keep unmatched old items that the user interacted with
    let preservedActionItems = old.actionItems.filter { item in
        !matchedOldActionIDs.contains(item.id) && (item.isCompleted || item.exportedToReminders)
    }

    // Merge events: preserve exportedToCalendar, id; prefer new date but fall back to old
    let mergedEvents = new.events.map { newEvent -> ExtractedEvent in
        if let match = old.events.first(where: {
            $0.title.localizedCaseInsensitiveCompare(newEvent.title) == .orderedSame
        }) {
            matchedOldEventIDs.insert(match.id)
            return ExtractedEvent(
                id: match.id,
                title: newEvent.title,
                date: newEvent.date ?? match.date,
                rawDateText: newEvent.rawDateText.isEmpty ? match.rawDateText : newEvent.rawDateText,
                exportedToCalendar: match.exportedToCalendar
            )
        }
        return newEvent
    }

    // Keep unmatched old events that were exported
    let preservedEvents = old.events.filter { event in
        !matchedOldEventIDs.contains(event.id) && event.exportedToCalendar
    }

    return Insights(
        summary: new.summary ?? old.summary,
        actionItems: mergedActionItems + preservedActionItems,
        events: mergedEvents + preservedEvents,
        keyPoints: new.keyPoints.isEmpty ? old.keyPoints : new.keyPoints
    )
}
