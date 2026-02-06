import Foundation

public struct ActionItem: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public var text: String
    public var isCompleted: Bool
    public var exportedToReminders: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        isCompleted: Bool = false,
        exportedToReminders: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isCompleted = isCompleted
        self.exportedToReminders = exportedToReminders
    }
}
