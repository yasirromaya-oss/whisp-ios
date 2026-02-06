import DXWhispKit
import SwiftUI

public struct TagChipView: View {
    let tag: Tag
    let isSelected: Bool

    public init(tag: Tag, isSelected: Bool = false) {
        self.tag = tag
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(tag.color.swiftUIColor.gradient)
                .frame(width: 8, height: 8)
                .shadow(color: tag.color.swiftUIColor.opacity(isSelected ? 0.6 : 0), radius: 4)

            Text(tag.name)
                .font(Theme.Typography.caption)
                .foregroundStyle(isSelected ? Theme.Colors.textPrimary : Theme.Colors.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.Spacing.sm + 2)
        .padding(.vertical, Theme.Spacing.xs + 1)
        .background {
            Capsule()
                .fill(isSelected ? AnyShapeStyle(tag.color.swiftUIColor.opacity(0.15)) : AnyShapeStyle(.ultraThinMaterial))
        }
        .overlay {
            Capsule()
                .strokeBorder(
                    isSelected
                        ? tag.color.swiftUIColor.opacity(0.4)
                        : Theme.Colors.innerBorderDark,
                    lineWidth: 0.5
                )
        }
        .shadow(color: isSelected ? tag.color.swiftUIColor.opacity(0.2) : .clear, radius: 6, y: 2)
        .contentShape(Capsule())
    }
}

extension TagChipView: Equatable {
    nonisolated public static func == (lhs: TagChipView, rhs: TagChipView) -> Bool {
        lhs.tag == rhs.tag && lhs.isSelected == rhs.isSelected
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack(spacing: 8) {
            TagChipView(tag: Tag(name: "Work", color: .blue), isSelected: true)
            TagChipView(tag: Tag(name: "Personal", color: .green))
            TagChipView(tag: Tag(name: "Ideas", color: .purple))
        }
        HStack(spacing: 8) {
            TagChipView(tag: Tag(name: "Urgent", color: .red), isSelected: true)
            TagChipView(tag: Tag(name: "Meeting", color: .teal))
            TagChipView(tag: Tag(name: "Project", color: .indigo), isSelected: true)
        }
    }
    .padding(Theme.Spacing.xl)
}
