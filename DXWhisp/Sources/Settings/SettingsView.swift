import ComposableArchitecture
import DXWhispKit
import DXWhispUI
import StoreKit
import SwiftUI

public struct SettingsView: View {
    @SwiftUI.Bindable var store: StoreOf<SettingsFeature>
    @State private var showManageSubscriptions = false

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                subscriptionSection
                integrationsSection
                aboutSection
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .onAppear { store.send(.onAppear) }
        .accessibilityIdentifier("settings_list")
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader(L10n.Subscription.pro)

            if store.isPro {
                VStack(spacing: 0) {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.Subscription.activeSubscription)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            if case .subscribed(_, let expiration) = store.subscriptionStatus,
                               let date = expiration {
                                Text("Renews \(date.formatted(.dateTime.month().day().year()))")
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textTertiary)
                            }
                        }

                        Spacer()
                    }
                    .padding(Theme.Spacing.lg)

                    Divider().opacity(0.3).padding(.horizontal, Theme.Spacing.lg)

                    Button {
                        showManageSubscriptions = true
                    } label: {
                        HStack {
                            Label(L10n.Subscription.manageSub, systemImage: "gear")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Spacer()

                            Image(systemName: "arrow.up.right")
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.accent)
                        }
                        .padding(Theme.Spacing.lg)
                        .contentShape(Rectangle())
                    }
                    .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
                }
                .glassCard()
            } else {
                Button {
                    store.send(.upgradeButtonTapped)
                } label: {
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.Subscription.upgrade)
                                .font(Theme.Typography.headline)
                                .foregroundStyle(Theme.Colors.textPrimary)

                            Text(L10n.Subscription.upgradeSubtitle)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.accent)
                    }
                    .padding(Theme.Spacing.lg)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .glassCard(isGlowing: true)
                .accessibilityIdentifier("upgrade_button")
            }
        }
    }

    // MARK: - Integrations

    private var integrationsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader(L10n.Settings.integrations)

            VStack(spacing: 0) {
                toggleRow(
                    title: L10n.Settings.autoExportActionItems,
                    icon: "checkmark.circle",
                    isOn: store.autoExportReminders,
                    isPro: store.isPro,
                    action: { store.send(.toggleAutoExportReminders) }
                )

                Divider().opacity(0.3).padding(.horizontal, Theme.Spacing.lg)

                toggleRow(
                    title: L10n.Settings.autoExportEvents,
                    icon: "calendar",
                    isOn: store.autoExportCalendar,
                    isPro: store.isPro,
                    action: { store.send(.toggleAutoExportCalendar) }
                )
            }
            .glassCard()
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            sectionHeader(L10n.Settings.about)

            VStack(spacing: 0) {
                if let url = URL(string: "https://yasirromaya.me") {
                    linkRow(title: L10n.Settings.developer, icon: "person", url: url)
                    Divider().opacity(0.3).padding(.horizontal, Theme.Spacing.lg)
                }

                if let url = URL(string: "https://doc-hosting.flycricket.io/dxwhisp-privacy-policy/0bd0065e-443c-4fc5-8be2-0fa3b1ccac52/privacy") {
                    linkRow(title: L10n.Settings.privacyPolicy, icon: "hand.raised", url: url)
                    Divider().opacity(0.3).padding(.horizontal, Theme.Spacing.lg)
                }

                if let url = URL(string: "https://doc-hosting.flycricket.io/dxwhisp-terms-of-use/016aea2b-4e94-41c4-8f5a-8a2b33bf7ac3/terms") {
                    linkRow(title: L10n.Settings.termsOfService, icon: "doc.text", url: url)
                    Divider().opacity(0.3).padding(.horizontal, Theme.Spacing.lg)
                }

                HStack {
                    Label(
                        L10n.Settings.version(Bundle.main.marketingVersion),
                        systemImage: "info.circle"
                    )
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                    Spacer()
                }
                .padding(Theme.Spacing.lg)
            }
            .glassCard()
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.Typography.caption)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textTertiary)
            .padding(.leading, Theme.Spacing.xs)
    }

    private func toggleRow(
        title: String,
        icon: String,
        isOn: Bool,
        isPro: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Label {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(title)
                    if !isPro {
                        Text(L10n.Subscription.pro)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.accent, in: Capsule())
                    }
                }
            } icon: {
                Image(systemName: icon)
            }
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textPrimary)

            Spacer()

            Toggle("", isOn: .init(get: { isOn }, set: { _ in action() }))
                .labelsHidden()
                .tint(Theme.Colors.accent)
        }
        .padding(Theme.Spacing.lg)
    }

    private func linkRow(title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Label(title, systemImage: icon)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.accent)
            }
            .padding(Theme.Spacing.lg)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView(store: Store(initialState: SettingsFeature.State()) {
            SettingsFeature()
        })
        .navigationTitle(L10n.Tab.settings)
    }
}

private extension Bundle {
    var marketingVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
