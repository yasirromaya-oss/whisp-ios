import Dependencies
import Foundation
import os
import StoreKit

public struct SubscriptionClient: Sendable {
    public var checkStatus: @Sendable () async -> SubscriptionStatus
    public var loadProducts: @Sendable () async throws -> [SubscriptionProduct]
    public var purchase: @Sendable (String) async throws -> SubscriptionPurchaseResult
    public var restorePurchases: @Sendable () async throws -> Void
    public var statusStream: @Sendable () -> AsyncStream<SubscriptionStatus>

    public init(
        checkStatus: @escaping @Sendable () async -> SubscriptionStatus,
        loadProducts: @escaping @Sendable () async throws -> [SubscriptionProduct],
        purchase: @escaping @Sendable (String) async throws -> SubscriptionPurchaseResult,
        restorePurchases: @escaping @Sendable () async throws -> Void,
        statusStream: @escaping @Sendable () -> AsyncStream<SubscriptionStatus>
    ) {
        self.checkStatus = checkStatus
        self.loadProducts = loadProducts
        self.purchase = purchase
        self.restorePurchases = restorePurchases
        self.statusStream = statusStream
    }
}

// MARK: - Live Implementation

/// Actor-isolated StoreKit 2 implementation.
/// All mutable state is protected by actor isolation.
private actor LiveSubscriptionActor {
    private static let logger = Logger(subsystem: "me.yasirromaya.whisp", category: "Subscription")

    // nonisolated(unsafe): UserDefaults.standard is thread-safe
    nonisolated(unsafe) private let defaults = UserDefaults.standard

    func checkStatus() async -> SubscriptionStatus {
        do {
            let statuses = try await Product.SubscriptionInfo.status(
                for: SubscriptionProductID.groupID
            )

            for status in statuses {
                guard case .verified(let transaction) = status.transaction else { continue }

                let renewalState = status.state
                let productID = transaction.productID
                let expirationDate = transaction.expirationDate

                let result: SubscriptionStatus
                if renewalState == .subscribed {
                    result = .subscribed(productID: productID, expirationDate: expirationDate)
                } else if renewalState == .inGracePeriod {
                    result = .inGracePeriod(productID: productID, expirationDate: expirationDate)
                } else if renewalState == .inBillingRetryPeriod {
                    result = .inBillingRetry(productID: productID, expirationDate: expirationDate)
                } else if renewalState == .expired {
                    result = .expired(productID: productID, expirationDate: expirationDate)
                } else if renewalState == .revoked {
                    result = .revoked
                } else {
                    continue
                }

                cacheProStatus(result.isPro)
                return result
            }
        } catch {
            Self.logger.warning("Failed to check subscription status: \(error.localizedDescription)")
        }

        cacheProStatus(false)
        return .notSubscribed
    }

    func loadProducts() async throws -> [SubscriptionProduct] {
        let products = try await Product.products(for: SubscriptionProductID.all)

        return products.compactMap { product -> SubscriptionProduct? in
            guard let subscription = product.subscription else { return nil }

            let period: SubscriptionProduct.Period
            switch subscription.subscriptionPeriod.unit {
            case .month:
                period = .monthly
            case .year:
                period = .yearly
            default:
                return nil
            }

            return SubscriptionProduct(
                id: product.id,
                displayName: product.displayName,
                description: product.description,
                displayPrice: product.displayPrice,
                price: product.price,
                period: period
            )
        }
        .sorted { lhs, _ in lhs.period == .monthly }
    }

    func purchase(productID: String) async throws -> SubscriptionPurchaseResult {
        let products = try await Product.products(for: [productID])
        guard let product = products.first else {
            throw SubscriptionError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            guard case .verified(let transaction) = verification else {
                throw SubscriptionError.verificationFailed
            }
            await transaction.finish()
            cacheProStatus(true)
            return .success

        case .pending:
            return .pending

        case .userCancelled:
            return .userCancelled

        @unknown default:
            return .userCancelled
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    nonisolated func statusStream() -> AsyncStream<SubscriptionStatus> {
        AsyncStream { continuation in
            let task = Task {
                for await verificationResult in Transaction.updates {
                    guard case .verified = verificationResult else { continue }
                    let status = await self.checkStatus()
                    continuation.yield(status)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func cacheProStatus(_ isPro: Bool) {
        defaults.set(isPro, forKey: UserDefaultsKey.isProCached.rawValue)
    }
}

extension SubscriptionClient: DependencyKey {
    public static let liveValue: SubscriptionClient = {
        let actor = LiveSubscriptionActor()
        return SubscriptionClient(
            checkStatus: { await actor.checkStatus() },
            loadProducts: { try await actor.loadProducts() },
            purchase: { try await actor.purchase(productID: $0) },
            restorePurchases: { try await actor.restorePurchases() },
            statusStream: { actor.statusStream() }
        )
    }()
}

extension SubscriptionClient: TestDependencyKey {
    public static let testValue = SubscriptionClient(
        checkStatus: { .notSubscribed },
        loadProducts: { [] },
        purchase: { _ in .userCancelled },
        restorePurchases: {},
        statusStream: { AsyncStream { $0.finish() } }
    )
}

public extension DependencyValues {
    var subscription: SubscriptionClient {
        get { self[SubscriptionClient.self] }
        set { self[SubscriptionClient.self] = newValue }
    }
}
