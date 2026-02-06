import Dependencies
import UIKit

public struct HapticClient: Sendable {
    public var impact: @MainActor @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) -> Void
    public var notification: @MainActor @Sendable (UINotificationFeedbackGenerator.FeedbackType) -> Void
    public var selection: @MainActor @Sendable () -> Void
}

extension HapticClient: DependencyKey {
    public static let liveValue = HapticClient(
        impact: { style in
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        },
        notification: { type in
            UINotificationFeedbackGenerator().notificationOccurred(type)
        },
        selection: {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    )

    /// No-ops — avoids unimplemented failures in existing tests that don't
    /// care about haptics.
    public static let testValue = HapticClient(
        impact: { _ in },
        notification: { _ in },
        selection: {}
    )
}

public extension DependencyValues {
    var haptic: HapticClient {
        get { self[HapticClient.self] }
        set { self[HapticClient.self] = newValue }
    }
}
