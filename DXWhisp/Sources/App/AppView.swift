import ComposableArchitecture
import DXWhispUI
import SwiftUI

public struct AppView: View {
    @SwiftUI.Bindable var store: StoreOf<AppFeature>

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.tab.sending(\.tabChanged)) {
            NavigationStack {
                NotesListView(store: store.scope(state: \.notesList, action: \.notesList))
                    .navigationTitle(L10n.App.title)
            }
            .tabItem {
                Label(L10n.Tab.notes, systemImage: "list.bullet")
            }
            .tag(AppFeature.State.Tab.notes)

            NavigationStack {
                RecordingView(store: store.scope(state: \.recording, action: \.recording))
                    .navigationTitle(L10n.Tab.record)
            }
            .tabItem {
                Label(L10n.Tab.record, systemImage: "waveform")
            }
            .tag(AppFeature.State.Tab.record)

            NavigationStack {
                SettingsView(store: store.scope(state: \.settings, action: \.settings))
                    .navigationTitle(L10n.Tab.settings)
            }
            .tabItem {
                Label(L10n.Tab.settings, systemImage: "gear")
            }
            .tag(AppFeature.State.Tab.settings)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.tab)
        .task { store.send(.checkSubscriptionStatus) }
        .onAppear {
            configureTabBarAppearance()
        }
        .sheet(item: $store.scope(state: \.currentNote, action: \.noteDetail)) { noteStore in
            NavigationStack {
                NoteDetailView(store: noteStore)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L10n.Common.done) {
                                store.send(.dismissNoteDetail)
                            }
                        }
                    }
            }
        }
        .sheet(item: $store.scope(state: \.paywall, action: \.paywall)) { paywallStore in
            NavigationStack {
                PaywallView(store: paywallStore)
                    .navigationTitle(L10n.Subscription.unlockPro)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
            .presentationDetents([.large])
        }
        .overlay {
            if let message = store.error {
                ErrorOverlay(
                    title: L10n.Common.somethingWentWrong,
                    message: message,
                    dismiss: { store.send(.dismissError) }
                )
            }
        }
    }

    private func configureTabBarAppearance() {
        #if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }
}

#Preview {
    AppView(store: Store(initialState: AppFeature.State()) {
        AppFeature()
    })
}
