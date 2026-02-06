import ComposableArchitecture
import DXWhispKit
import Foundation
import os
import UIKit

@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var tab: Tab = .notes
        public var recording: RecordingFeature.State = .init()
        public var notesList: NotesListFeature.State = .init()
        public var settings: SettingsFeature.State = .init()
        @Presents public var currentNote: NoteDetailFeature.State?
        public var error: String?

        public enum Tab: Equatable, Sendable {
            case notes, record, settings
        }

        public init() {}
    }

    public enum Action: Sendable {
        case tabChanged(State.Tab)
        case recording(RecordingFeature.Action)
        case notesList(NotesListFeature.Action)
        case noteDetail(PresentationAction<NoteDetailFeature.Action>)
        case settings(SettingsFeature.Action)
        case processRecording(URL, TimeInterval)
        case transcriptionCompleted(VoiceNote)
        case transcriptionFailed(String)
        case dismissNoteDetail
        case dismissError
        case lockedNoteAuthSucceeded(VoiceNote)
        case lockedNoteAuthFailed
    }

    @Dependency(\.transcription) var transcription
    @Dependency(\.persistence) var persistence
    @Dependency(\.eventKit) var eventKit
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date
    @Dependency(\.haptic) var haptic
    @Dependency(\.biometric) var biometric

    private static let logger = Logger(subsystem: "me.yasirromaya.whisp", category: "AppFeature")
    private enum CancelID { case transcription, biometricAuth }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.recording, action: \.recording) {
            RecordingFeature()
        }

        Scope(state: \.notesList, action: \.notesList) {
            NotesListFeature()
        }

        Scope(state: \.settings, action: \.settings) {
            SettingsFeature()
        }

        Reduce { state, action in
            switch action {
            case let .tabChanged(tab):
                state.tab = tab
                return .none

            case let .recording(.delegate(.recordingCompleted(url, duration))):
                state.recording.recordingState = .idle
                state.recording.currentDuration = 0
                state.recording.postRecording = .transcribing
                return .send(.processRecording(url, duration))

            case let .recording(.delegate(.viewNote(note))):
                state.currentNote = NoteDetailFeature.State(note: note)
                return .none

            case .recording:
                return .none

            case let .processRecording(url, duration):
                let autoExportReminders = state.settings.autoExportReminders
                let autoExportCalendar = state.settings.autoExportCalendar
                return .run { [uuid, date] send in
                    // Protect transcription pipeline from app suspension
                    let bgTaskID = await UIApplication.shared.beginBackgroundTask(
                        withName: "Transcription"
                    )
                    defer {
                        if bgTaskID != .invalid {
                            Task { @MainActor in
                                UIApplication.shared.endBackgroundTask(bgTaskID)
                            }
                        }
                    }

                    do {
                        let result = try await transcription.transcribe(url)
                        var noteInsights: Insights?
                        if !result.text.isEmpty {
                            noteInsights = try await transcription.extractInsights(result.text)
                        }

                        // Auto-export action items to Reminders
                        if autoExportReminders, let items = noteInsights?.actionItems, !items.isEmpty {
                            let granted = await eventKit.requestRemindersAccess()
                            if granted {
                                for var item in items {
                                    do {
                                        try await eventKit.addReminder(item.text, nil)
                                        item.exportedToReminders = true
                                        if let idx = noteInsights?.actionItems.firstIndex(where: { $0.id == item.id }) {
                                            noteInsights?.actionItems[idx] = item
                                        }
                                    } catch {
                                        Self.logger.warning("Auto-export reminder failed: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }

                        // Auto-export events to Calendar
                        if autoExportCalendar, let events = noteInsights?.events, !events.isEmpty {
                            let granted = await eventKit.requestCalendarAccess()
                            if granted {
                                for var event in events {
                                    guard let eventDate = event.date else { continue }
                                    do {
                                        try await eventKit.addCalendarEvent(event.title, eventDate, nil)
                                        event.exportedToCalendar = true
                                        if let idx = noteInsights?.events.firstIndex(where: { $0.id == event.id }) {
                                            noteInsights?.events[idx] = event
                                        }
                                    } catch {
                                        Self.logger.warning("Auto-export calendar event failed: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }

                        let note = VoiceNote(
                            id: uuid(),
                            createdAt: date.now,
                            title: generateTitle(from: result.text),
                            audioFilename: url.lastPathComponent,
                            duration: duration,
                            transcription: result,
                            insights: noteInsights
                        )

                        try await persistence.saveNote(note)
                        await send(.transcriptionCompleted(note))
                    } catch {
                        if !(error is CancellationError) {
                            await send(.transcriptionFailed(error.localizedDescription))
                        }
                    }
                }
                .cancellable(id: CancelID.transcription, cancelInFlight: true)

            case let .transcriptionFailed(message):
                state.recording.postRecording = .failed(message)
                return .none

            case .dismissError:
                state.error = nil
                return .none

            case let .lockedNoteAuthSucceeded(note):
                var detailState = NoteDetailFeature.State(note: note)
                detailState.isAuthenticated = true
                state.currentNote = detailState
                return .none

            case .lockedNoteAuthFailed:
                return .none

            case let .transcriptionCompleted(note):
                state.notesList.notes.insert(note, at: 0)
                state.notesList.recomputeFilteredNotes()
                state.recording.postRecording = .completed(note)
                return .run { @MainActor _ in haptic.notification(.success) }

            case let .notesList(.noteTapped(note)):
                if note.isLocked {
                    return .run { send in
                        do {
                            let success = try await biometric.authenticate(L10n.App.authenticateToView)
                            if success {
                                await send(.lockedNoteAuthSucceeded(note))
                            } else {
                                await send(.lockedNoteAuthFailed)
                            }
                        } catch {
                            await send(.lockedNoteAuthFailed)
                        }
                    }
                    .cancellable(id: CancelID.biometricAuth, cancelInFlight: true)
                }
                state.currentNote = NoteDetailFeature.State(note: note)
                return .none

            case .notesList:
                return .none

            case let .noteDetail(.presented(.delegate(.noteUpdated(note)))):
                state.notesList.notes[id: note.id] = note
                state.notesList.recomputeFilteredNotes()
                if case .completed(let existing) = state.recording.postRecording, existing.id == note.id {
                    state.recording.postRecording = .completed(note)
                }
                return .none

            case let .noteDetail(.presented(.delegate(.noteDeleted(id)))):
                state.notesList.notes.remove(id: id)
                state.notesList.recomputeFilteredNotes()
                state.currentNote = nil
                if case .completed(let note) = state.recording.postRecording, note.id == id {
                    state.recording.postRecording = nil
                }
                return .none

            case .noteDetail:
                return .none

            case .dismissNoteDetail:
                state.currentNote = nil
                return .none

            case .settings:
                return .none
            }
        }
        .ifLet(\.$currentNote, action: \.noteDetail) {
            NoteDetailFeature()
        }
    }
}

private func generateTitle(from text: String) -> String {
    let words = text.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .prefix(5)

    guard !words.isEmpty else { return L10n.App.voiceNote }
    return words.joined(separator: " ") + (words.count >= 5 ? "..." : "")
}
