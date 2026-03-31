import ComposableArchitecture
import DXWhispKit
import DXWhispUI
import SwiftUI

public struct NoteDetailView: View {
    @SwiftUI.Bindable var store: StoreOf<NoteDetailFeature>
    @State private var shareText: String?

    public init(store: StoreOf<NoteDetailFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.note.isLocked && !store.isAuthenticated {
                lockScreen
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                mainContent
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.isAuthenticated)
        .navigationTitle(store.note.title.isEmpty ? L10n.App.voiceNote : store.note.title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .toolbar {
                if !store.note.isLocked || store.isAuthenticated {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                store.send(.toggleLock)
                            } label: {
                                Label(
                                    store.note.isLocked
                                        ? L10n.NoteDetail.unlockNote
                                        : "\(L10n.NoteDetail.lockNote)\(!store.isPro && !store.note.isLocked ? " (\(L10n.Subscription.pro))" : "")",
                                    systemImage: store.note.isLocked ? "lock.open" : "lock"
                                )
                            }

                            if store.note.transcription != nil {
                                Button {
                                    shareText = formatShareText(store.note)
                                } label: {
                                    Label(L10n.NoteDetail.share, systemImage: "square.and.arrow.up")
                                }
                            }

                            Button(role: .destructive) {
                                store.send(.deleteButtonTapped)
                            } label: {
                                Label(L10n.Common.delete, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                        }
                    }
                }
            }
            .confirmationDialog(
                L10n.NoteDetail.deleteNote,
                isPresented: $store.showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Common.delete, role: .destructive) {
                    store.send(.confirmDelete)
                }
            } message: {
                Text(L10n.Common.actionCannotBeUndone)
            }
            .overlay {
                if let message = store.errorMessage {
                    ErrorOverlay(
                        title: L10n.Common.somethingWentWrong,
                        message: message,
                        dismiss: { store.send(.dismissError) }
                    )
                }
            }
            .sheet(isPresented: Binding(
                get: { shareText != nil },
                set: { if !$0 { shareText = nil } }
            )) {
                if let text = shareText {
                    ShareSheet(items: [text])
                        .presentationDetents([.medium, .large])
                }
            }
    }

    // MARK: - Lock Screen

    private var lockScreen: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Colors.textTertiary)

            Text(L10n.NoteDetail.noteLocked)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textSecondary)

            Button {
                store.send(.authenticationRequired)
            } label: {
                Text(L10n.NoteDetail.authenticate)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(
                        Theme.Colors.accentGradient,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                    )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                playbackSection

                if let transcription = store.note.transcription {
                    transcriptionSection(transcription)
                }

                if store.isReExtractingInsights {
                    HStack(spacing: Theme.Spacing.sm) {
                        ProgressView()
                            .tint(Theme.Colors.accent)
                        Text(L10n.NoteDetail.reExtracting)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Theme.Spacing.lg)
                    .glassCard()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                if let insights = store.note.insights {
                    insightsSection(insights)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
    }

    // MARK: - Playback

    private var playbackSection: some View {
        VStack(spacing: Theme.Spacing.lg) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)

                    Capsule()
                        .fill(Theme.Colors.accentGradient)
                        .frame(width: max(0, geometry.size.width * store.playbackProgress), height: 6)
                        .animation(.linear(duration: 0.1), value: store.playbackProgress)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            store.send(.seek(progress))
                        }
                )
            }
            .frame(height: 24)
            .accessibilityElement()
            .accessibilityLabel(L10n.NoteDetail.playbackScrubber)
            .accessibilityValue("\(Int(store.playbackProgress * 100))%")
            .accessibilityAdjustableAction { direction in
                let step: Double = 0.05
                switch direction {
                case .increment:
                    store.send(.seek(min(1, store.playbackProgress + step)))
                case .decrement:
                    store.send(.seek(max(0, store.playbackProgress - step)))
                @unknown default:
                    break
                }
            }

            HStack {
                Text(formatTime(store.currentTime))
                    .font(Theme.Typography.mono)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Spacer()

                Button {
                    store.send(.playPauseTapped)
                } label: {
                    Image(systemName: store.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(Color.accentColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(store.isPlaying ? L10n.NoteDetail.pause : L10n.NoteDetail.play)

                Spacer()

                Text(formatTime(store.note.duration))
                    .font(Theme.Typography.mono)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(Theme.Spacing.lg)
        .glassCard()
    }

    // MARK: - Transcription

    private func transcriptionSection(_ transcription: Transcription) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Label(L10n.NoteDetail.transcription, systemImage: "text.alignleft")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                if store.isEditingTranscript {
                    Button(L10n.Common.cancel) {
                        store.send(.cancelEditTranscript, animation: .easeInOut(duration: 0.25))
                    }
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)

                    Button(L10n.Common.save) {
                        store.send(.saveTranscript, animation: .easeInOut(duration: 0.25))
                    }
                    .font(Theme.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.Colors.accent)
                } else {
                    Button {
                        store.send(.editTranscriptTapped, animation: .easeInOut(duration: 0.25))
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
            }

            Divider().opacity(0.3)

            if store.isEditingTranscript {
                TextEditor(text: $store.editedTranscriptText)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .transition(.opacity)
            } else if !transcription.speakerTurns.isEmpty {
                ForEach(transcription.speakerTurns) { turn in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(turn.speakerLabel)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fontWeight(.semibold)
                        Text(turn.text)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .textSelection(.enabled)
                    }
                }
            } else {
                Text(transcription.text)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .textSelection(.enabled)
                    .transition(.opacity)
            }
        }
        .padding(Theme.Spacing.lg)
        .glassCard()
    }

    // MARK: - Insights

    private func insightsSection(_ insights: Insights) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            if let summary = insights.summary {
                insightCard(label: L10n.NoteDetail.summary, icon: "doc.text") {
                    Text(summary)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
            }

            if !insights.actionItems.isEmpty {
                insightCard(label: L10n.NoteDetail.actionItems, icon: "checkmark.circle") {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(insights.actionItems) { item in
                            ActionItemRow(
                                item: item,
                                onToggle: { store.send(.toggleActionItemCompleted(item.id)) },
                                onExport: { store.send(.exportToReminders(item)) }
                            )
                        }
                    }
                }
            }

            if !insights.events.isEmpty {
                insightCard(label: L10n.NoteDetail.datesAndEvents, icon: "calendar") {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(insights.events) { event in
                            EventRow(event: event) {
                                store.send(.exportToCalendar(event))
                            }
                        }
                    }
                }
            }

            if !insights.keyPoints.isEmpty {
                insightCard(label: L10n.NoteDetail.keyPoints, icon: "lightbulb") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(insights.keyPoints.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Text("\(index + 1)")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 20, alignment: .trailing)

                                Text(insights.keyPoints[index])
                                    .font(Theme.Typography.body)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func insightCard<Content: View>(
        label: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label(label, systemImage: icon)
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .glassCard()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatShareText(_ note: VoiceNote) -> String {
        var parts: [String] = [note.title]

        if let transcription = note.transcription {
            parts.append("\n\(transcription.text)")
        }

        if let insights = note.insights {
            if let summary = insights.summary {
                parts.append("\n\(L10n.NoteDetail.summary): \(summary)")
            }
            if !insights.actionItems.isEmpty {
                let items = insights.actionItems.map { "- \($0.text)" }.joined(separator: "\n")
                parts.append("\n\(L10n.NoteDetail.actionItems):\n\(items)")
            }
            if !insights.events.isEmpty {
                let events = insights.events.map { "- \($0.title)\($0.rawDateText.isEmpty ? "" : " (\($0.rawDateText))")" }.joined(separator: "\n")
                parts.append("\n\(L10n.NoteDetail.events):\n\(events)")
            }
            if !insights.keyPoints.isEmpty {
                let points = insights.keyPoints.map { "- \($0)" }.joined(separator: "\n")
                parts.append("\n\(L10n.NoteDetail.keyPoints):\n\(points)")
            }
        }

        return parts.joined(separator: "\n")
    }
}

// MARK: - Action Item Row

private struct ActionItemRow: View {
    let item: ActionItem
    let onToggle: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onToggle) {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isCompleted ? Color.accentColor : Theme.Colors.textTertiary)
            }
            .buttonStyle(.plain)

            Text(item.text)
                .font(Theme.Typography.body)
                .strikethrough(item.isCompleted)
                .foregroundStyle(item.isCompleted ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)

            Spacer()

            if !item.exportedToReminders {
                Button(action: onExport) {
                    Text(L10n.NoteDetail.reminders)
                        .font(Theme.Typography.caption)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Theme.Colors.innerBorder, lineWidth: 1))
                }
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .font(Theme.Typography.caption)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

extension ActionItemRow: Equatable {
    nonisolated static func == (lhs: ActionItemRow, rhs: ActionItemRow) -> Bool {
        lhs.item == rhs.item
    }
}

// MARK: - Event Row

private struct EventRow: View {
    let event: ExtractedEvent
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(event.rawDateText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1), in: Capsule())
            }

            Spacer()

            if !event.exportedToCalendar {
                Button(action: onExport) {
                    Text(L10n.NoteDetail.calendar)
                        .font(Theme.Typography.caption)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Theme.Colors.innerBorder, lineWidth: 1))
                }
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .font(Theme.Typography.caption)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

extension EventRow: Equatable {
    nonisolated static func == (lhs: EventRow, rhs: EventRow) -> Bool {
        lhs.event == rhs.event
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        NoteDetailView(
            store: Store(
                initialState: NoteDetailFeature.State(
                    note: VoiceNote(
                        title: "Meeting Notes",
                        audioFilename: "test.m4a",
                        duration: 125,
                        transcription: Transcription(
                            text: "We discussed the project timeline. Need to finish by Friday. The team will meet again next Monday at 2pm."
                        ),
                        insights: Insights(
                            summary: "Project timeline discussion with team.",
                            actionItems: [
                                ActionItem(text: "Finish project by Friday"),
                                ActionItem(text: "Prepare presentation"),
                            ],
                            events: [
                                ExtractedEvent(title: "Team Meeting", date: nil, rawDateText: "next Monday at 2pm"),
                            ],
                            keyPoints: [
                                "Project deadline is Friday",
                                "Team meeting scheduled",
                            ]
                        )
                    )
                )
            ) {
                NoteDetailFeature()
            }
        )
    }
}
