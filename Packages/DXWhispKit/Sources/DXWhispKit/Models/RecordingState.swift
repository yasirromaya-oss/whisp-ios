import Foundation

public enum RecordingState: Equatable, Sendable {
    case idle
    case recording(duration: TimeInterval)
    case processing
}
