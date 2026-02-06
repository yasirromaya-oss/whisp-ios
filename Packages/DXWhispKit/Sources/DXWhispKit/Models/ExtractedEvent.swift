import Foundation

public struct ExtractedEvent: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var date: Date?
    public var rawDateText: String
    public var exportedToCalendar: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        date: Date? = nil,
        rawDateText: String,
        exportedToCalendar: Bool = false
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.rawDateText = rawDateText
        self.exportedToCalendar = exportedToCalendar
    }
}
