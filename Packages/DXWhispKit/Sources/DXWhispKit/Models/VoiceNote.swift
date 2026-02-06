import Foundation

public struct VoiceNote: Equatable, Sendable, Identifiable, Codable {
    public let id: UUID
    public let createdAt: Date
    public var title: String
    public let audioFilename: String
    public let duration: TimeInterval
    public var transcription: Transcription?
    public var insights: Insights?
    public var isFavorite: Bool
    public var isLocked: Bool
    public var tagIDs: [UUID]

    /// Resolves `audioFilename` against the user's Documents/Audio directory.
    public var audioURL: URL {
        Self.audioDirectory.appendingPathComponent(audioFilename)
    }

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        audioFilename: String,
        duration: TimeInterval,
        transcription: Transcription? = nil,
        insights: Insights? = nil,
        isFavorite: Bool = false,
        isLocked: Bool = false,
        tagIDs: [UUID] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.audioFilename = audioFilename
        self.duration = duration
        self.transcription = transcription
        self.insights = insights
        self.isFavorite = isFavorite
        self.isLocked = isLocked
        self.tagIDs = tagIDs
    }

    /// Custom decoder for backward compatibility — `isLocked` defaults to `false`
    /// when absent from older JSON files.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        audioFilename = try container.decode(String.self, forKey: .audioFilename)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        transcription = try container.decodeIfPresent(Transcription.self, forKey: .transcription)
        insights = try container.decodeIfPresent(Insights.self, forKey: .insights)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
    }

    /// Stable audio directory: ~/Documents/Audio/
    public static let audioDirectory: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Audio", isDirectory: true)
    }()
}
