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
        @Presents public var paywall: SubscriptionFeature.State?
        public var isPro: Bool = false
        public var subscriptionStatus: SubscriptionStatus = .unknown
        public var error: String?

        public enum Tab: Equatable, Sendable {
            case notes, record, settings
        }

        /// Number of recordings created in the current calendar month.
        public var monthlyRecordingCount: Int {
            let calendar = Calendar.current
            let now = Date()
            return notesList.notes.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }.count
        }

        public init() {}
    }

    public enum Action: Sendable {
        case tabChanged(State.Tab)
        case recording(RecordingFeature.Action)
        case notesList(NotesListFeature.Action)
        case noteDetail(PresentationAction<NoteDetailFeature.Action>)
        case settings(SettingsFeature.Action)
        case paywall(PresentationAction<SubscriptionFeature.Action>)
        case processRecording(URL, TimeInterval)
        case transcriptionCompleted(VoiceNote)
        case transcriptionFailed(String)
        case dismissNoteDetail
        case dismissError
        case lockedNoteAuthSucceeded(VoiceNote)
        case lockedNoteAuthFailed
        case checkSubscriptionStatus
        case subscriptionStatusUpdated(SubscriptionStatus)
        case showPaywall
    }

    @Dependency(\.transcription) var transcription
    @Dependency(\.persistence) var persistence
    @Dependency(\.eventKit) var eventKit
    @Dependency(\.uuid) var uuid
    @Dependency(\.date) var date
    @Dependency(\.haptic) var haptic
    @Dependency(\.biometric) var biometric
    @Dependency(\.subscription) var subscription
    @Dependency(\.userDefaults) var userDefaults

    private static let logger = Logger(subsystem: "me.yasirromaya.whisp", category: "AppFeature")
    private enum CancelID { case transcription, biometricAuth, subscriptionMonitor }

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

            // MARK: - Subscription

            case .checkSubscriptionStatus:
                // Read cached value for instant UI
                state.isPro = userDefaults.getBool(.isProCached)
                syncIsProToChildren(&state)
                return .merge(
                    .run { send in
                        let status = await subscription.checkStatus()
                        await send(.subscriptionStatusUpdated(status))
                    },
                    .run { send in
                        for await status in subscription.statusStream() {
                            await send(.subscriptionStatusUpdated(status))
                        }
                    }
                    .cancellable(id: CancelID.subscriptionMonitor, cancelInFlight: true)
                )

            case let .subscriptionStatusUpdated(status):
                let wasPro = state.isPro
                state.subscriptionStatus = status
                state.isPro = status.isPro
                syncIsProToChildren(&state)

                // If downgraded, disable auto-export
                if wasPro && !status.isPro {
                    state.settings.autoExportReminders = false
                    state.settings.autoExportCalendar = false
                    userDefaults.setBool(.autoExportReminders, false)
                    userDefaults.setBool(.autoExportCalendar, false)
                }
                return .none

            case .showPaywall:
                state.paywall = SubscriptionFeature.State()
                return .none

            case .paywall(.presented(.delegate(.subscriptionActivated))):
                state.isPro = true
                state.subscriptionStatus = .subscribed(productID: "", expirationDate: nil)
                syncIsProToChildren(&state)
                state.paywall = nil
                return .none

            case .paywall:
                return .none

            // MARK: - Recording Delegates

            case let .recording(.delegate(.recordingCompleted(url, duration))):
                state.recording.recordingState = .idle
                state.recording.currentDuration = 0
                state.recording.postRecording = .transcribing
                return .send(.processRecording(url, duration))

            case let .recording(.delegate(.viewNote(note))):
                var detailState = NoteDetailFeature.State(note: note)
                detailState.isPro = state.isPro
                state.currentNote = detailState
                return .none

            case .recording(.delegate(.paywallRequested)):
                return .send(.showPaywall)

            case .recording:
                return .none

            // MARK: - Process Recording

            case let .processRecording(url, duration):
                let autoExportReminders = state.settings.autoExportReminders && state.isPro
                let autoExportCalendar = state.settings.autoExportCalendar && state.isPro
                let isPro = state.isPro
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
                        var result = try await transcription.transcribe(url)

                        // Free users: strip speaker detection data
                        if !isPro {
                            result = Transcription(
                                text: result.text,
                                segments: [],
                                speakerTurns: []
                            )
                        }

                        // Only extract insights for Pro users
                        var noteInsights: Insights?
                        if isPro, !result.text.isEmpty {
                            noteInsights = try await transcription.extractInsights(result.text)
                        }

                        // Auto-export action items to Reminders (Pro only)
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

                        // Auto-export events to Calendar (Pro only)
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
                detailState.isPro = state.isPro
                state.currentNote = detailState
                return .none

            case .lockedNoteAuthFailed:
                return .none

            case let .transcriptionCompleted(note):
                state.notesList.notes.insert(note, at: 0)
                state.notesList.recomputeFilteredNotes()
                state.recording.postRecording = .completed(note)
                // Sync monthly count after adding note
                state.recording.monthlyRecordingCount = state.monthlyRecordingCount
                return .run { @MainActor _ in haptic.notification(.success) }

            // MARK: - Notes List

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
                var detailState = NoteDetailFeature.State(note: note)
                detailState.isPro = state.isPro
                state.currentNote = detailState
                return .none

            case .notesList(.delegate(.paywallRequested)):
                return .send(.showPaywall)

            case .notesList:
                return .none

            // MARK: - Note Detail

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
                // Sync monthly count after deletion
                state.recording.monthlyRecordingCount = state.monthlyRecordingCount
                return .none

            case .noteDetail(.presented(.delegate(.paywallRequested))):
                return .send(.showPaywall)

            case .noteDetail:
                return .none

            case .dismissNoteDetail:
                state.currentNote = nil
                return .none

            // MARK: - Settings

            case .settings(.delegate(.paywallRequested)):
                return .send(.showPaywall)

            case .settings:
                return .none
            }
        }
        .ifLet(\.$currentNote, action: \.noteDetail) {
            NoteDetailFeature()
        }
        .ifLet(\.$paywall, action: \.paywall) {
            SubscriptionFeature()
        }
    }

    /// Syncs isPro and monthlyRecordingCount to child feature states.
    private func syncIsProToChildren(_ state: inout State) {
        let isPro = state.isPro
        let monthlyCount = state.monthlyRecordingCount
        let subscriptionStatus = state.subscriptionStatus
        state.recording.isPro = isPro
        state.recording.monthlyRecordingCount = monthlyCount
        state.notesList.isPro = isPro
        state.settings.isPro = isPro
        state.settings.subscriptionStatus = subscriptionStatus
        if state.currentNote != nil {
            state.currentNote?.isPro = isPro
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
