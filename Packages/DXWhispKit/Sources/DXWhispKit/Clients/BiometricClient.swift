import Dependencies
import Foundation
import LocalAuthentication

public enum BiometricType: Sendable {
    case none
    case faceID
    case touchID
    case opticID
}

public struct BiometricClient: Sendable {
    public var isAvailable: @Sendable () -> Bool
    public var biometricType: @Sendable () -> BiometricType
    public var authenticate: @Sendable (String) async throws -> Bool
}

extension BiometricClient: DependencyKey {
    public static let liveValue = BiometricClient(
        isAvailable: {
            let context = LAContext()
            return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        },
        biometricType: {
            let context = LAContext()
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                return .none
            }
            switch context.biometryType {
            case .faceID: return .faceID
            case .touchID: return .touchID
            case .opticID: return .opticID
            default: return .none
            }
        },
        authenticate: { reason in
            let context = LAContext()
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        }
    )

    public static let testValue = BiometricClient(
        isAvailable: { true },
        biometricType: { .faceID },
        authenticate: { _ in true }
    )
}

public extension DependencyValues {
    var biometric: BiometricClient {
        get { self[BiometricClient.self] }
        set { self[BiometricClient.self] = newValue }
    }
}
