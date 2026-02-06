import ComposableArchitecture
import DXWhispKit

@Reducer
public struct RootFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var hasCompletedOnboarding: Bool = false
        public var hasLoaded: Bool = false
        public var onboarding: OnboardingFeature.State = .init()
        public var app: AppFeature.State = .init()

        public init(hasCompletedOnboarding: Bool = false) {
            self.hasCompletedOnboarding = hasCompletedOnboarding
        }
    }

    public enum Action: Sendable {
        case onboarding(OnboardingFeature.Action)
        case app(AppFeature.Action)
        case loadOnboardingStatus
        case setOnboardingCompleted(Bool)
    }

    @Dependency(\.userDefaults) var userDefaults

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.onboarding, action: \.onboarding) {
            OnboardingFeature()
        }
        Scope(state: \.app, action: \.app) {
            AppFeature()
        }
        Reduce { state, action in
            switch action {
            case .loadOnboardingStatus:
                let completed = userDefaults.getBool(.hasCompletedOnboarding)
                return .send(.setOnboardingCompleted(completed))

            case .onboarding(.completeOnboarding):
                state.hasCompletedOnboarding = true
                // Fire-and-forget: UserDefaults.set is synchronous and effectively infallible
                return .run { [userDefaults] _ in
                    userDefaults.setBool(.hasCompletedOnboarding, true)
                }

            case .onboarding, .app:
                return .none

            case let .setOnboardingCompleted(completed):
                state.hasCompletedOnboarding = completed
                state.hasLoaded = true
                return .none
            }
        }
    }
}
