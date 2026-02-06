import Foundation

public struct TranscriptionSegment: Equatable, Sendable, Codable {
    public let text: String
    public let timestamp: TimeInterval
    public let duration: TimeInterval
    public let confidence: Float

    public init(text: String, timestamp: TimeInterval, duration: TimeInterval, confidence: Float) {
        self.text = text
        self.timestamp = timestamp
        self.duration = duration
        self.confidence = confidence
    }
}

public struct SpeakerTurn: Equatable, Sendable, Codable, Identifiable {
    public var id: String { "\(speakerLabel)-\(startTime)" }
    public let speakerLabel: String
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(speakerLabel: String, text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.speakerLabel = speakerLabel
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct Transcription: Equatable, Sendable, Codable {
    public let text: String
    public let segments: [TranscriptionSegment]
    public let speakerTurns: [SpeakerTurn]

    public init(
        text: String,
        segments: [TranscriptionSegment] = [],
        speakerTurns: [SpeakerTurn] = []
    ) {
        self.text = text
        self.segments = segments
        self.speakerTurns = speakerTurns
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        segments = try container.decodeIfPresent([TranscriptionSegment].self, forKey: .segments) ?? []
        speakerTurns = try container.decodeIfPresent([SpeakerTurn].self, forKey: .speakerTurns) ?? []
    }
}
