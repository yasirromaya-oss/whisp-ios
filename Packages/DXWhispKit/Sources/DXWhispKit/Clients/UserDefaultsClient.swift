import Dependencies
import Foundation

public struct UserDefaultsClient: Sendable {
    public var getBool: @Sendable (UserDefaultsKey) -> Bool
    public var setBool: @Sendable (UserDefaultsKey, Bool) -> Void
    public var optionalBool: @Sendable (UserDefaultsKey) -> Bool?

    public init(
        getBool: @escaping @Sendable (UserDefaultsKey) -> Bool,
        setBool: @escaping @Sendable (UserDefaultsKey, Bool) -> Void,
        optionalBool: @escaping @Sendable (UserDefaultsKey) -> Bool?
    ) {
        self.getBool = getBool
        self.setBool = setBool
        self.optionalBool = optionalBool
    }
}

extension UserDefaultsClient: DependencyKey {
    public static let liveValue: UserDefaultsClient = {
        // nonisolated(unsafe): UserDefaults.standard is a thread-safe singleton
        nonisolated(unsafe) let defaults = UserDefaults.standard
        return UserDefaultsClient(
            getBool: { defaults.bool(forKey: $0.rawValue) },
            setBool: { defaults.set($1, forKey: $0.rawValue) },
            optionalBool: { key in
                guard defaults.object(forKey: key.rawValue) != nil else { return nil }
                return defaults.bool(forKey: key.rawValue)
            }
        )
    }()

    public static let testValue = UserDefaultsClient(
        getBool: { _ in false },
        setBool: { _, _ in },
        optionalBool: { _ in nil }
    )
}

public extension DependencyValues {
    var userDefaults: UserDefaultsClient {
        get { self[UserDefaultsClient.self] }
        set { self[UserDefaultsClient.self] = newValue }
    }
}
