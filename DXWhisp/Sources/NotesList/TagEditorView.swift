import ComposableArchitecture
import DXWhispKit
import DXWhispUI
import SwiftUI

struct TagEditorView: View {
    @SwiftUI.Bindable var store: StoreOf<TagEditorFeature>
    @FocusState private var isNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                // Preview
                tagPreview

                // Name Section
                nameSection

                // Color Section
                colorSection
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.lg)
        }
        .navigationTitle(store.isNew ? L10n.TagEditor.newTag : L10n.TagEditor.editTag)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.Common.cancel) {
                    store.send(.cancelTapped)
                }
                .foregroundStyle(Theme.Colors.textSecondary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.save) {
                    store.send(.saveTapped)
                }
                .fontWeight(.semibold)
                .foregroundStyle(Theme.Colors.accent)
                .disabled(store.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { isNameFocused = store.isNew }
    }

    // MARK: - Tag Preview

    private var tagPreview: some View {
        VStack(spacing: Theme.Spacing.md) {
            let previewName = store.name.trimmingCharacters(in: .whitespacesAndNewlines)
            TagChipView(
                tag: Tag(
                    id: store.tagID,
                    name: previewName.isEmpty ? L10n.TagEditor.tagName : previewName,
                    color: store.color
                ),
                isSelected: true
            )
            .scaleEffect(1.3)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.color)

            Text(L10n.TagEditor.preview)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxl)
        .glassCard()
    }

    // MARK: - Name Section

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(L10n.TagEditor.name)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)

            TextField(L10n.TagEditor.enterTagName, text: $store.name)
                .font(Theme.Typography.body)
                .padding(Theme.Spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .strokeBorder(Theme.Colors.innerBorder, lineWidth: 0.5)
                }
                .focused($isNameFocused)
        }
    }

    // MARK: - Color Section

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(L10n.TagEditor.color)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.lg), count: 5), spacing: Theme.Spacing.lg) {
                ForEach(TagColor.allCases, id: \.self) { color in
                    colorButton(for: color)
                }
            }
            .padding(Theme.Spacing.lg)
            .glassCard(cornerRadius: Theme.Radius.section)
        }
    }

    private func colorButton(for color: TagColor) -> some View {
        Button {
            store.send(.binding(.set(\.color, color)))
        } label: {
            ZStack {
                Circle()
                    .fill(color.swiftUIColor.gradient)
                    .frame(width: 40, height: 40)
                    .shadow(
                        color: store.color == color ? color.swiftUIColor.opacity(0.5) : .clear,
                        radius: 8,
                        y: 2
                    )

                if store.color == color {
                    Circle()
                        .strokeBorder(.white.opacity(0.6), lineWidth: 2.5)
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: store.color == color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color.rawValue)
    }
}

#Preview {
    NavigationStack {
        TagEditorView(
            store: Store(initialState: TagEditorFeature.State()) {
                TagEditorFeature()
            }
        )
    }
}
