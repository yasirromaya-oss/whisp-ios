import ComposableArchitecture
import DXWhispUI
import SwiftUI

public struct OnboardingView: View {
    @SwiftUI.Bindable var store: StoreOf<OnboardingFeature>

    public init(store: StoreOf<OnboardingFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $store.currentPage.sending(\.pageChanged)) {
                ForEach(0..<store.pages.count, id: \.self) { index in
                    PageView(page: store.pages[index])
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut, value: store.currentPage)

            VStack(spacing: Theme.Spacing.xxl) {
                // Page indicator — capsule pills
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(0 ..< store.pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == store.currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: index == store.currentPage ? 24 : 8, height: 8)
                            .animation(.spring(response: 0.35), value: store.currentPage)
                    }
                }

                // Action button with gradient
                Button {
                    if store.currentPage == store.pages.count - 1 {
                        store.send(.requestPermissions)
                    } else {
                        store.send(.nextPage)
                    }
                } label: {
                    Text(store.currentPage == store.pages.count - 1 ? L10n.Onboarding.getStarted : L10n.Onboarding.continueButton)
                        .font(Theme.Typography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.lg)
                        .background(Theme.Colors.accentGradient, in: RoundedRectangle(cornerRadius: Theme.Radius.section, style: .continuous))
                        .foregroundStyle(.white)
                        .shadow(color: Theme.Colors.subtleGlow, radius: 12, x: 0, y: 4)
                }
                .accessibilityIdentifier("onboarding_continue")

                if store.currentPage < store.pages.count - 1 {
                    Button(L10n.Onboarding.skip) {
                        store.send(.completeOnboarding)
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .accessibilityIdentifier("onboarding_skip")
                }
            }
            .padding(Theme.Spacing.xxl)
        }
        .background {
            LinearGradient(
                colors: [Color.clear, Color.accentColor.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct PageView: View {
    let page: OnboardingFeature.OnboardingPage

    var body: some View {
        VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.pulse, options: .repeating)
                .padding(Theme.Spacing.xxl)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(Circle().stroke(Theme.Colors.innerBorder, lineWidth: 1))
                        .shadow(color: Theme.Colors.subtleGlow, radius: 16, x: 0, y: 0)
                )

            VStack(spacing: Theme.Spacing.lg) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xxxl)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView(
        store: Store(initialState: OnboardingFeature.State()) {
            OnboardingFeature()
        }
    )
}
