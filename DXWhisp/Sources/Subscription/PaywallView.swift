import ComposableArchitecture
import DXWhispKit
import DXWhispUI
import SwiftUI

public struct PaywallView: View {
    @SwiftUI.Bindable var store: StoreOf<SubscriptionFeature>

    public init(store: StoreOf<SubscriptionFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xxl) {
                headerSection
                featureListSection
                planCardsSection
                subscribeButton
                restoreLink
                legalLinks
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .onAppear { store.send(.onAppear) }
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

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "crown.fill")
                .font(.system(size: 52))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, Theme.Spacing.lg)

            Text(L10n.Subscription.unlockPro)
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(L10n.Subscription.subtitle)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature List

    private var featureListSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            featureRow(icon: "mic.fill", text: L10n.Subscription.featureUnlimitedRecordings)
            featureRow(icon: "person.2.fill", text: L10n.Subscription.featureSpeakerDetection)
            featureRow(icon: "brain", text: L10n.Subscription.featureAIInsights)
            featureRow(icon: "arrow.right.circle.fill", text: L10n.Subscription.featureAutoExport)
            featureRow(icon: "tag.fill", text: L10n.Subscription.featureUnlimitedTags)
            featureRow(icon: "lock.fill", text: L10n.Subscription.featureBiometricLock)
        }
        .padding(Theme.Spacing.lg)
        .glassCard()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.Colors.accent)
                .frame(width: 28, alignment: .center)

            Text(text)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
        }
    }

    // MARK: - Plan Cards

    private var planCardsSection: some View {
        VStack(spacing: Theme.Spacing.md) {
            if store.isLoading {
                ProgressView()
                    .tint(Theme.Colors.accent)
                    .padding(Theme.Spacing.xxl)
            } else {
                ForEach(store.products) { product in
                    planCard(product: product)
                }
            }
        }
    }

    private func planCard(product: SubscriptionProduct) -> some View {
        let isSelected = store.selectedProductID == product.id
        let isYearly = product.period == .yearly

        return Button {
            store.send(.selectProduct(product.id))
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text(product.displayName)
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if isYearly {
                            Text(L10n.Subscription.save40)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, 2)
                                .background(.green, in: Capsule())
                        }
                    }

                    Text(product.description)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.lg)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(
                        isSelected ? Theme.Colors.accent : Theme.Colors.innerBorder,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan_card_\(product.id)")
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            store.send(.purchaseTapped)
        } label: {
            Group {
                if store.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(L10n.Subscription.subscribe)
                        .font(Theme.Typography.headline)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.md)
            .background(
                Theme.Colors.accentGradient,
                in: RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
            )
        }
        .disabled(store.isPurchasing || store.products.isEmpty)
        .modifier(Theme.Shadow.glow())
        .accessibilityIdentifier("subscribe_button")
    }

    // MARK: - Restore

    private var restoreLink: some View {
        Button {
            store.send(.restoreTapped)
        } label: {
            if store.isRestoring {
                ProgressView()
                    .tint(Theme.Colors.textSecondary)
            } else {
                Text(L10n.Subscription.restorePurchases)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
        }
        .disabled(store.isRestoring)
        .accessibilityIdentifier("restore_button")
    }

    // MARK: - Legal

    private var legalLinks: some View {
        HStack(spacing: Theme.Spacing.lg) {
            if let url = URL(string: "https://doc-hosting.flycricket.io/dxwhisp-terms-of-use/016aea2b-4e94-41c4-8f5a-8a2b33bf7ac3/terms") {
                Link(L10n.Settings.termsOfService, destination: url)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            if let url = URL(string: "https://doc-hosting.flycricket.io/dxwhisp-privacy-policy/0bd0065e-443c-4fc5-8be2-0fa3b1ccac52/privacy") {
                Link(L10n.Settings.privacyPolicy, destination: url)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
        .padding(.bottom, Theme.Spacing.lg)
    }
}

#Preview {
    PaywallView(
        store: Store(initialState: SubscriptionFeature.State()) {
            SubscriptionFeature()
        }
    )
}
