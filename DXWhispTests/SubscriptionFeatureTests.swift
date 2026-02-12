import ComposableArchitecture
import DXWhispKit
import Foundation
import Testing

@testable import DXWhisp

private let monthlyProduct = SubscriptionProduct(
    id: SubscriptionProductID.monthly,
    displayName: "Monthly",
    description: "Monthly subscription",
    displayPrice: "$6.99",
    price: 6.99,
    period: .monthly
)

private let yearlyProduct = SubscriptionProduct(
    id: SubscriptionProductID.yearly,
    displayName: "Yearly",
    description: "Yearly subscription",
    displayPrice: "$49.99",
    price: 49.99,
    period: .yearly
)

@MainActor
struct SubscriptionFeatureTests {
    @Test func onAppearLoadsProducts() async {
        let store = TestStore(initialState: SubscriptionFeature.State()) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.loadProducts = { [monthlyProduct, yearlyProduct] }
        }
        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.productsLoaded) {
            $0.isLoading = false
            $0.products = [monthlyProduct, yearlyProduct]
        }
    }

    @Test func onAppearSkipsIfAlreadyLoaded() async {
        var state = SubscriptionFeature.State()
        state.products = [monthlyProduct]
        let store = TestStore(initialState: state) {
            SubscriptionFeature()
        }
        await store.send(.onAppear)
    }

    @Test func productsLoadFailedShowsError() async {
        let store = TestStore(initialState: SubscriptionFeature.State()) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.loadProducts = { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"]) }
        }
        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.productsLoadFailed) {
            $0.isLoading = false
            $0.error = "Network error"
        }
    }

    @Test func selectProductUpdatesSelection() async {
        let store = TestStore(initialState: SubscriptionFeature.State()) {
            SubscriptionFeature()
        }
        await store.send(.selectProduct(SubscriptionProductID.monthly)) {
            $0.selectedProductID = SubscriptionProductID.monthly
        }
    }

    @Test func defaultSelectionIsYearly() {
        let state = SubscriptionFeature.State()
        #expect(state.selectedProductID == SubscriptionProductID.yearly)
    }

    @Test func purchaseSuccessSendsDelegateAndHaptic() async {
        var state = SubscriptionFeature.State()
        state.products = [monthlyProduct, yearlyProduct]
        let store = TestStore(initialState: state) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.purchase = { _ in .success }
        }
        await store.send(.purchaseTapped) {
            $0.isPurchasing = true
        }
        await store.receive(\.purchaseResult) {
            $0.isPurchasing = false
            $0.purchaseSucceeded = true
        }
        await store.receive(\.delegate.subscriptionActivated)
    }

    @Test func purchasePendingShowsMessage() async {
        var state = SubscriptionFeature.State()
        state.products = [yearlyProduct]
        let store = TestStore(initialState: state) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.purchase = { _ in .pending }
        }
        await store.send(.purchaseTapped) {
            $0.isPurchasing = true
        }
        await store.receive(\.purchaseResult) {
            $0.isPurchasing = false
            $0.error = L10n.Subscription.purchasePending
        }
    }

    @Test func purchaseUserCancelledNoError() async {
        var state = SubscriptionFeature.State()
        state.products = [yearlyProduct]
        let store = TestStore(initialState: state) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.purchase = { _ in .userCancelled }
        }
        await store.send(.purchaseTapped) {
            $0.isPurchasing = true
        }
        await store.receive(\.purchaseResult) {
            $0.isPurchasing = false
        }
    }

    @Test func purchaseFailedShowsError() async {
        var state = SubscriptionFeature.State()
        state.products = [yearlyProduct]
        let store = TestStore(initialState: state) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.purchase = { _ in throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Payment failed"]) }
        }
        await store.send(.purchaseTapped) {
            $0.isPurchasing = true
        }
        await store.receive(\.purchaseFailed) {
            $0.isPurchasing = false
            $0.error = "Payment failed"
        }
    }

    @Test func restoreSuccessWithProSendsDelegate() async {
        let store = TestStore(initialState: SubscriptionFeature.State()) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.restorePurchases = {}
            $0.subscription.checkStatus = { .subscribed(productID: "test", expirationDate: nil) }
        }
        await store.send(.restoreTapped) {
            $0.isRestoring = true
        }
        await store.receive(\.restoreCompleted) {
            $0.isRestoring = false
            $0.purchaseSucceeded = true
        }
        await store.receive(\.delegate.subscriptionActivated)
    }

    @Test func restoreSuccessWithoutProShowsMessage() async {
        let store = TestStore(initialState: SubscriptionFeature.State()) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.restorePurchases = {}
            $0.subscription.checkStatus = { .notSubscribed }
        }
        await store.send(.restoreTapped) {
            $0.isRestoring = true
        }
        await store.receive(\.restoreCompleted) {
            $0.isRestoring = false
            $0.error = L10n.Subscription.noActiveSubscription
        }
    }

    @Test func restoreFailedShowsError() async {
        let store = TestStore(initialState: SubscriptionFeature.State()) {
            SubscriptionFeature()
        } withDependencies: {
            $0.subscription.restorePurchases = { throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Restore failed"]) }
        }
        await store.send(.restoreTapped) {
            $0.isRestoring = true
        }
        await store.receive(\.restoreFailed) {
            $0.isRestoring = false
            $0.error = "Restore failed"
        }
    }

    @Test func dismissErrorClearsError() async {
        var state = SubscriptionFeature.State()
        state.error = "Some error"
        let store = TestStore(initialState: state) {
            SubscriptionFeature()
        }
        await store.send(.dismissError) {
            $0.error = nil
        }
    }
}
