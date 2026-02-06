import ComposableArchitecture
import DXWhispKit
import DXWhispUI
import SwiftUI

public struct NotesListView: View {
    @SwiftUI.Bindable var store: StoreOf<NotesListFeature>

    public init(store: StoreOf<NotesListFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.isLoading {
                ProgressView()
            } else if let error = store.loadError {
                ContentUnavailableView {
                    Label(L10n.Common.somethingWentWrong, systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button(L10n.Common.tryAgain) {
                        store.send(.onAppear)
                    }
                }
            } else if store.notes.isEmpty {
                emptyState
            } else {
                notesContent
            }
        }
        .searchable(text: $store.searchText, prompt: L10n.NotesList.searchPrompt)
        .onAppear {
            store.send(.onAppear)
        }
        .alert(
            L10n.NotesList.renameNote,
            isPresented: Binding(
                get: { store.renamingNoteID != nil },
                set: { if !$0 { store.send(.cancelRename) } }
            )
        ) {
            TextField(L10n.NotesList.noteTitle, text: $store.renameText)
            Button(L10n.Common.rename) { store.send(.confirmRename) }
            Button(L10n.Common.cancel, role: .cancel) { store.send(.cancelRename) }
        }
        .confirmationDialog(
            L10n.NotesList.deleteSelectedTitle(store.selectedNoteIDs.count),
            isPresented: $store.showDeleteSelectedConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.Common.delete, role: .destructive) { store.send(.confirmDeleteSelected) }
            Button(L10n.Common.cancel, role: .cancel) { store.send(.cancelDeleteSelected) }
        } message: {
            Text(L10n.Common.actionCannotBeUndone)
        }
        .confirmationDialog(
            L10n.NotesList.deleteAllTitle(store.notes.count),
            isPresented: $store.showDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.NotesList.deleteAll, role: .destructive) { store.send(.confirmDeleteAll) }
            Button(L10n.Common.cancel, role: .cancel) { store.send(.cancelDeleteAll) }
        } message: {
            Text(L10n.NotesList.deleteAllConfirmMessage)
        }
        .sheet(item: $store.scope(state: \.tagEditor, action: \.tagEditor)) { tagEditorStore in
            NavigationStack {
                TagEditorView(store: tagEditorStore)
            }
            .presentationDetents([.medium])
        }
        .overlay(alignment: .bottom) {
            if let operationError = store.operationError {
                Text(operationError)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onTapGesture {
                        store.send(.dismissOperationError, animation: .easeInOut(duration: 0.2))
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.operationError)
        .animation(.easeInOut(duration: 0.2), value: store.selectedNoteIDs)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(Theme.Colors.accent)
                .symbolEffect(.breathe)
                .padding(Theme.Spacing.xxl)
                .glassCard(cornerRadius: 28)

            VStack(spacing: Theme.Spacing.sm) {
                Text(L10n.NotesList.emptyTitle)
                    .font(Theme.Typography.title)

                Text(L10n.NotesList.emptySubtitle)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .accessibilityIdentifier("notes_empty_state")
    }

    private var notesContent: some View {
        VStack(spacing: 0) {
            tagFilterBar

            if store.isEditing {
                editOptionsBar
            }

            if store.filteredNotes.isEmpty {
                filteredEmptyState
            } else {
                ScrollView {
                    let favorites = store.filteredFavorites
                    let others = store.filteredOthers

                    // Precompute tag colors once per render instead of per-note in ForEach
                    let tagColorMap: [VoiceNote.ID: [Color]] = {
                        var map: [VoiceNote.ID: [Color]] = [:]
                        map.reserveCapacity(store.filteredNotes.count)
                        for note in store.filteredNotes {
                            map[note.id] = note.tagIDs.compactMap { store.allTags[id: $0]?.color.swiftUIColor }
                        }
                        return map
                    }()

                    LazyVStack(spacing: Theme.Spacing.lg) {
                        if !favorites.isEmpty {
                            notesSection(title: L10n.NotesList.favorites, notes: favorites, tagColorMap: tagColorMap)
                        }

                        if !others.isEmpty {
                            notesSection(title: favorites.isEmpty ? nil : L10n.NotesList.allNotes, notes: others, tagColorMap: tagColorMap)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.lg)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.filteredNotes.count)
                }
            }
        }
    }

    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label(
                !store.selectedFilterTagIDs.isEmpty ? L10n.NotesList.noMatchingNotes : L10n.NotesList.noResults,
                systemImage: !store.selectedFilterTagIDs.isEmpty ? "tag.slash" : "magnifyingglass"
            )
        } description: {
            if !store.selectedFilterTagIDs.isEmpty && !store.searchText.isEmpty {
                Text(L10n.NotesList.noMatchTagsAndSearch)
            } else if !store.selectedFilterTagIDs.isEmpty {
                Text(L10n.NotesList.noMatchTags)
            } else {
                Text(L10n.NotesList.noMatchSearch(store.searchText))
            }
        } actions: {
            if !store.selectedFilterTagIDs.isEmpty {
                Button {
                    store.send(.clearTagFilter, animation: .easeInOut(duration: 0.2))
                } label: {
                    Text(L10n.NotesList.clearTagFilter)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.accent)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Tag Filter Bar

    private var tagFilterBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        store.send(.createTagTapped)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text(L10n.NotesList.tag)
                                .font(Theme.Typography.caption)
                        }
                        .foregroundStyle(Theme.Colors.accent)
                        .padding(.horizontal, Theme.Spacing.sm + 2)
                        .padding(.vertical, Theme.Spacing.xs + 1)
                        .background {
                            Capsule()
                                .strokeBorder(Theme.Colors.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        }
                    }

                    if !store.allTags.isEmpty {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Theme.Colors.innerBorder)
                            .frame(width: 1, height: 16)
                            .padding(.horizontal, 2)
                    }

                    ForEach(store.allTags) { tag in
                        let isSelected = store.selectedFilterTagIDs.contains(tag.id)
                        TagChipView(
                            tag: tag,
                            isSelected: isSelected
                        )
                        .onTapGesture {
                            store.send(.toggleFilterTag(tag.id), animation: .easeInOut(duration: 0.2))
                        }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityLabel("\(tag.name) filter")
                        .contextMenu {
                            Button {
                                store.send(.editTagTapped(tag))
                            } label: {
                                Label(L10n.NotesList.editTag, systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                store.send(.deleteTagTapped(tag))
                            } label: {
                                Label(L10n.NotesList.deleteTag, systemImage: "trash")
                            }
                        }
                    }

                    if !store.selectedFilterTagIDs.isEmpty {
                        Button {
                            store.send(.clearTagFilter, animation: .easeInOut(duration: 0.2))
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                Text(L10n.NotesList.clear)
                                    .font(Theme.Typography.caption)
                            }
                            .foregroundStyle(Theme.Colors.accent)
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, Theme.Spacing.xs + 1)
                            .background(Theme.Colors.accent.opacity(0.1), in: Capsule())
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
                .padding(.leading, Theme.Spacing.xl)
                .padding(.vertical, Theme.Spacing.md)
            }

            if !store.notes.isEmpty {
                Button {
                    store.send(.editButtonTapped, animation: .easeInOut(duration: 0.25))
                } label: {
                    Image(systemName: store.isEditing ? "checkmark.circle.fill" : "pencil.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(store.isEditing ? Theme.Colors.accent : Theme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, Theme.Spacing.sm)
            }
        }
    }

    // MARK: - Edit Options Bar

    private var editOptionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                let isAllSelected = !store.filteredNotes.isEmpty
                    && store.selectedNoteIDs.count == store.filteredNotes.count

                editChip(
                    icon: isAllSelected ? "checkmark.circle.fill" : "circle",
                    title: isAllSelected ? L10n.NotesList.deselectAll : L10n.NotesList.selectAll
                ) {
                    if isAllSelected {
                        store.send(.deselectAll)
                    } else {
                        store.send(.selectAll)
                    }
                }

                if !store.allTags.isEmpty {
                    tagMenuChip
                }

                editChip(
                    icon: "lock",
                    title: L10n.NotesList.lock,
                    isDisabled: store.selectedNoteIDs.isEmpty
                ) {
                    store.send(.lockSelected)
                }

                editChip(
                    icon: "trash",
                    title: !store.selectedNoteIDs.isEmpty
                        ? L10n.NotesList.deleteCount(store.selectedNoteIDs.count)
                        : L10n.Common.delete,
                    isDestructive: true,
                    isDisabled: store.selectedNoteIDs.isEmpty
                ) {
                    store.send(.deleteSelectedTapped)
                }

                editChip(
                    icon: "trash.fill",
                    title: L10n.NotesList.deleteAll,
                    isDestructive: true
                ) {
                    store.send(.deleteAllTapped)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var tagMenuChip: some View {
        let isDisabled = store.selectedNoteIDs.isEmpty
        return Menu {
            ForEach(store.allTags) { tag in
                Button {
                    store.send(.toggleTagOnSelected(tag.id))
                } label: {
                    Label(tag.name, systemImage: "tag")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "tag")
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.NotesList.tag)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .foregroundStyle(
                isDisabled ? Theme.Colors.textTertiary : Theme.Colors.accent
            )
            .background(
                isDisabled
                    ? Theme.Colors.textTertiary.opacity(0.08)
                    : Theme.Colors.accent.opacity(0.1),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isDisabled
                            ? Theme.Colors.textTertiary.opacity(0.15)
                            : Theme.Colors.accent.opacity(0.2),
                        lineWidth: 0.5
                    )
            }
        }
        .disabled(isDisabled)
    }

    private func editChip(
        icon: String,
        title: String,
        isDestructive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            .foregroundStyle(
                isDisabled ? Theme.Colors.textTertiary
                    : isDestructive ? .red
                    : Theme.Colors.accent
            )
            .background(
                isDisabled ? Theme.Colors.textTertiary.opacity(0.08)
                    : isDestructive ? Color.red.opacity(0.1)
                    : Theme.Colors.accent.opacity(0.1),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .strokeBorder(
                        isDisabled ? Theme.Colors.textTertiary.opacity(0.15)
                            : isDestructive ? Color.red.opacity(0.2)
                            : Theme.Colors.accent.opacity(0.2),
                        lineWidth: 0.5
                    )
            }
        }
        .disabled(isDisabled)
    }

    // MARK: - Notes Section

    private func notesSection(title: String?, notes: [VoiceNote], tagColorMap: [VoiceNote.ID: [Color]]) -> some View {
        Section {
            ForEach(notes) { note in
                NoteCard(
                    note: note,
                    tagColors: tagColorMap[note.id] ?? [],
                    isEditing: store.isEditing,
                    isSelected: store.selectedNoteIDs.contains(note.id)
                ) {
                    if store.isEditing {
                        if store.selectedNoteIDs.contains(note.id) {
                            store.send(.deselectNote(note.id), animation: .spring(response: 0.3, dampingFraction: 0.7))
                        } else {
                            store.send(.selectNote(note.id), animation: .spring(response: 0.3, dampingFraction: 0.7))
                        }
                    } else {
                        store.send(.noteTapped(note))
                    }
                }
                .transition(.asymmetric(
                    insertion: .slide.combined(with: .opacity),
                    removal: .opacity
                ))
                .contextMenu {
                    if !store.isEditing && !note.isLocked {
                        Button {
                            store.send(.toggleFavorite(note))
                        } label: {
                            Label(
                                note.isFavorite ? L10n.NotesList.removeFromFavorites : L10n.NotesList.addToFavorites,
                                systemImage: note.isFavorite ? "star.slash" : "star"
                            )
                        }

                        Button {
                            store.send(.toggleLock(note))
                        } label: {
                            Label(L10n.NotesList.lock, systemImage: "lock")
                        }

                        Button {
                            store.send(.renameNoteTapped(note))
                        } label: {
                            Label(L10n.Common.rename, systemImage: "pencil")
                        }

                        if !store.allTags.isEmpty {
                            Menu {
                                ForEach(store.allTags) { tag in
                                    Button {
                                        store.send(.toggleTagOnNote(tag.id, note.id))
                                    } label: {
                                        HStack {
                                            Text(tag.name)
                                            if note.tagIDs.contains(tag.id) {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Label(L10n.NotesList.tags, systemImage: "tag")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            store.send(.deleteNote(note))
                        } label: {
                            Label(L10n.Common.delete, systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            if let title {
                Text(title)
                    .font(Theme.Typography.caption)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.sm)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotesListView(
            store: Store(initialState: NotesListFeature.State()) {
                NotesListFeature()
            }
        )
        .navigationTitle(L10n.Tab.notes)
    }
}
