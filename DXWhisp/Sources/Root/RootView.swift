import ComposableArchitecture
import SwiftUI

public struct RootView: View {
    @SwiftUI.Bindable var store: StoreOf<RootFeature>

    public init(store: StoreOf<RootFeature>) {
        self.store = store
    }

    public var body: some View {
        Group {
            if !store.hasLoaded {
                // Blank screen matching launch screen — no flash
                Color(.systemBackground)
                    .ignoresSafeArea()
            } else if store.hasCompletedOnboarding {
                AppView(store: store.scope(state: \.app, action: \.app))
            } else {
                OnboardingView(store: store.scope(state: \.onboarding, action: \.onboarding))
            }
        }
        .onAppear {
            store.send(.loadOnboardingStatus)
        }
    }
}

#Preview {
    RootView(store: Store(initialState: RootFeature.State(hasCompletedOnboarding: false)) {
        RootFeature()
    })
}
