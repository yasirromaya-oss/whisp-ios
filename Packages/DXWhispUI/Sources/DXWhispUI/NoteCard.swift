import DXWhispKit
import SwiftUI

public struct NoteCard: View {
    let note: VoiceNote
    let tagColors: [Color]
    let isEditing: Bool
    let isSelected: Bool
    let onTap: () -> Void

    public init(
        note: VoiceNote,
        tagColors: [Color] = [],
        isEditing: Bool = false,
        isSelected: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.note = note
        self.tagColors = tagColors
        self.isEditing = isEditing
        self.isSelected = isSelected
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                if isEditing {
                    selectionIndicator
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.sm + 2) {
                    titleRow

                    if let transcription = note.transcription {
                        Text(transcription.text)
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    metadataRow
                }
            }
            .padding(Theme.Spacing.lg)
            .glassCard()
            .overlay {
                if isEditing && isSelected {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .strokeBorder(Theme.Colors.accent, lineWidth: 2)
                } else if !tagColors.isEmpty {
                    tagBorder
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("note_card")
    }

    // MARK: - Selection Indicator

    private var selectionIndicator: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Theme.Colors.accent : .clear)
                .frame(width: 24, height: 24)

            Circle()
                .strokeBorder(
                    isSelected ? Theme.Colors.accent : Theme.Colors.textTertiary.opacity(0.5),
                    lineWidth: isSelected ? 0 : 1.5
                )
                .frame(width: 24, height: 24)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    // MARK: - Tag Border

    @ViewBuilder
    private var tagBorder: some View {
        if tagColors.count == 1 {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(tagColors[0].opacity(0.4), lineWidth: 1.5)
        } else {
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: Array(tagColors.prefix(2).map { $0.opacity(0.4) }),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }

    // MARK: - Title Row

    private var titleRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text(note.title.isEmpty ? L10nUI.voiceNote : note.title)
                .font(.system(.body, weight: .semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)

            Spacer()

            if note.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

        }
    }

    // MARK: - Metadata Row

    private var metadataRow: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text(formatDuration(note.duration))
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Text(note.createdAt, style: .date)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

extension NoteCard: Equatable {
    nonisolated public static func == (lhs: NoteCard, rhs: NoteCard) -> Bool {
        lhs.note == rhs.note
            && lhs.tagColors == rhs.tagColors
            && lhs.isEditing == rhs.isEditing
            && lhs.isSelected == rhs.isSelected
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.lg) {
        NoteCard(
            note: VoiceNote(
                id: UUID(),
                createdAt: Date(),
                title: "Meeting Notes",
                audioFilename: "test.m4a",
                duration: 125,
                transcription: Transcription(text: "Sample transcription text that shows how the card looks with content."),
            ),
            tagColors: [.blue, .red],
            onTap: {}
        )

        NoteCard(
            note: VoiceNote(
                id: UUID(),
                createdAt: Date(),
                title: "Shopping List",
                audioFilename: "test2.m4a",
                duration: 45,
                transcription: Transcription(text: "Pick up groceries after work.")
            ),
            tagColors: [.green],
            isEditing: true,
            isSelected: true,
            onTap: {}
        )
    }
    .padding(Theme.Spacing.xl)
}
