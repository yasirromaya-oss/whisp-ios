import Foundation

// MARK: - Product IDs

public enum SubscriptionProductID: Sendable {
    public static let monthly = "me.yasirromaya.whisp.pro.monthly"
    public static let yearly = "me.yasirromaya.whisp.pro.yearly"
    public static let groupID = "dxwhisp_pro"

    public static let all: Set<String> = [monthly, yearly]
}

// MARK: - Subscription Status

public enum SubscriptionStatus: Equatable, Sendable {
    case unknown
    case notSubscribed
    case subscribed(productID: String, expirationDate: Date?)
    case expired(productID: String, expirationDate: Date?)
    case inGracePeriod(productID: String, expirationDate: Date?)
    case inBillingRetry(productID: String, expirationDate: Date?)
    case revoked

    public var isPro: Bool {
        switch self {
        case .subscribed, .inGracePeriod:
            true
        default:
            false
        }
    }
}

// MARK: - Subscription Product (testable wrapper)

public struct SubscriptionProduct: Equatable, Identifiable, Sendable {
    public let id: String
    public let displayName: String
    public let description: String
    public let displayPrice: String
    public let price: Decimal
    public let period: Period

    public enum Period: Equatable, Sendable {
        case monthly
        case yearly
    }

    public init(
        id: String,
        displayName: String,
        description: String,
        displayPrice: String,
        price: Decimal,
        period: Period
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.price = price
        self.period = period
    }
}

// MARK: - Purchase Result

public enum SubscriptionPurchaseResult: Equatable, Sendable {
    case success
    case pending
    case userCancelled
}

// MARK: - Errors

public enum SubscriptionError: Error, Equatable, Sendable {
    case productNotFound
    case verificationFailed
    case purchaseFailed(String)
}
