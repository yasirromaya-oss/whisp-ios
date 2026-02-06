import ComposableArchitecture
import DXWhispKit
import Foundation

@Reducer
public struct OnboardingFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var currentPage: Int = 0
        public var microphonePermissionGranted: Bool?

        public let pages: [OnboardingPage] = [
            OnboardingPage(
                icon: "waveform",
                title: L10n.Onboarding.recordAnythingTitle,
                subtitle: L10n.Onboarding.recordAnythingSubtitle
            ),
            OnboardingPage(
                icon: "person.2.wave.2",
                title: L10n.Onboarding.speakerDetectionTitle,
                subtitle: L10n.Onboarding.speakerDetectionSubtitle
            ),
            OnboardingPage(
                icon: "checklist",
                title: L10n.Onboarding.insightsTitle,
                subtitle: L10n.Onboarding.insightsSubtitle
            ),
            OnboardingPage(
                icon: "lock.shield",
                title: L10n.Onboarding.securityTitle,
                subtitle: L10n.Onboarding.securitySubtitle
            ),
        ]

        public init() {}
    }

    public struct OnboardingPage: Equatable, Sendable {
        public let icon: String
        public let title: String
        public let subtitle: String
    }

    public enum Action: Sendable {
        case nextPage
        case previousPage
        case pageChanged(Int)
        case requestPermissions
        case microphonePermissionResult(Bool)
        case completeOnboarding
    }

    @Dependency(\.audioRecorder) var audioRecorder

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .nextPage:
                if state.currentPage < state.pages.count - 1 {
                    state.currentPage += 1
                }
                return .none

            case .previousPage:
                if state.currentPage > 0 {
                    state.currentPage -= 1
                }
                return .none

            case let .pageChanged(page):
                state.currentPage = page
                return .none

            case .requestPermissions:
                return .run { send in
                    let micGranted = await audioRecorder.requestPermission()
                    await send(.microphonePermissionResult(micGranted))
                }

            case let .microphonePermissionResult(granted):
                state.microphonePermissionGranted = granted
                return .send(.completeOnboarding)

            case .completeOnboarding:
                return .none
            }
        }
    }
}
