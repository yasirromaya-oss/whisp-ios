import ComposableArchitecture
import DXWhispKit
import Foundation

@Reducer
public struct SubscriptionFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var products: [SubscriptionProduct] = []
        public var selectedProductID: String = SubscriptionProductID.yearly
        public var isLoading: Bool = false
        public var isPurchasing: Bool = false
        public var isRestoring: Bool = false
        public var error: String?
        public var purchaseSucceeded: Bool = false

        public init() {}
    }

    public enum Action: Sendable {
        case onAppear
        case productsLoaded([SubscriptionProduct])
        case productsLoadFailed(String)
        case selectProduct(String)
        case purchaseTapped
        case purchaseResult(SubscriptionPurchaseResult)
        case purchaseFailed(String)
        case restoreTapped
        case restoreCompleted(SubscriptionStatus)
        case restoreFailed(String)
        case dismissError
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Sendable {
            case subscriptionActivated
        }
    }

    @Dependency(\.subscription) var subscription
    @Dependency(\.haptic) var haptic

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard state.products.isEmpty, !state.isLoading else { return .none }
                state.isLoading = true
                return .run { send in
                    do {
                        let products = try await subscription.loadProducts()
                        await send(.productsLoaded(products))
                    } catch {
                        await send(.productsLoadFailed(error.localizedDescription))
                    }
                }

            case let .productsLoaded(products):
                state.isLoading = false
                state.products = products
                return .none

            case let .productsLoadFailed(message):
                state.isLoading = false
                state.error = message
                return .none

            case let .selectProduct(productID):
                state.selectedProductID = productID
                return .run { @MainActor _ in haptic.selection() }

            case .purchaseTapped:
                guard !state.isPurchasing else { return .none }
                state.isPurchasing = true
                state.error = nil
                let productID = state.selectedProductID
                return .run { send in
                    do {
                        let result = try await subscription.purchase(productID)
                        await send(.purchaseResult(result))
                    } catch {
                        await send(.purchaseFailed(error.localizedDescription))
                    }
                }

            case let .purchaseResult(result):
                state.isPurchasing = false
                switch result {
                case .success:
                    state.purchaseSucceeded = true
                    return .merge(
                        .run { @MainActor _ in haptic.notification(.success) },
                        .send(.delegate(.subscriptionActivated))
                    )
                case .pending:
                    state.error = L10n.Subscription.purchasePending
                    return .none
                case .userCancelled:
                    return .none
                }

            case let .purchaseFailed(message):
                state.isPurchasing = false
                state.error = message
                return .none

            case .restoreTapped:
                guard !state.isRestoring else { return .none }
                state.isRestoring = true
                state.error = nil
                return .run { send in
                    do {
                        try await subscription.restorePurchases()
                        let status = await subscription.checkStatus()
                        await send(.restoreCompleted(status))
                    } catch {
                        await send(.restoreFailed(error.localizedDescription))
                    }
                }

            case let .restoreCompleted(status):
                state.isRestoring = false
                if status.isPro {
                    state.purchaseSucceeded = true
                    return .merge(
                        .run { @MainActor _ in haptic.notification(.success) },
                        .send(.delegate(.subscriptionActivated))
                    )
                }
                state.error = L10n.Subscription.noActiveSubscription
                return .none

            case let .restoreFailed(message):
                state.isRestoring = false
                state.error = message
                return .none

            case .dismissError:
                state.error = nil
                return .none

            case .delegate:
                return .none
            }
        }
    }
}
