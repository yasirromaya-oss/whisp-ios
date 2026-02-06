import Foundation

public struct Insights: Equatable, Sendable, Codable {
    public var summary: String?
    public var actionItems: [ActionItem]
    public var events: [ExtractedEvent]
    public var keyPoints: [String]

    public init(
        summary: String? = nil,
        actionItems: [ActionItem] = [],
        events: [ExtractedEvent] = [],
        keyPoints: [String] = []
    ) {
        self.summary = summary
        self.actionItems = actionItems
        self.events = events
        self.keyPoints = keyPoints
    }
}
