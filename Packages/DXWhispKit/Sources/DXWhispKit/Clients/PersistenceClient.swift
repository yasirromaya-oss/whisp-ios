import Dependencies
import Foundation
import OSLog

// MARK: - Client Interface

public struct PersistenceClient: Sendable {
    public var saveNote: @Sendable (VoiceNote) async throws -> Void
    public var loadNotes: @Sendable () async throws -> [VoiceNote]
    public var deleteNote: @Sendable (VoiceNote) async throws -> Void
    public var updateNote: @Sendable (VoiceNote) async throws -> Void
    public var cleanupOrphanedAudio: @Sendable () async -> Int
    public var saveTags: @Sendable ([Tag]) async throws -> Void
    public var loadTags: @Sendable () async throws -> [Tag]
}

// MARK: - Errors

public enum PersistenceError: Error, Equatable, LocalizedError {
    case encodingFailed
    case writeFailed(String)
    case readFailed(String)
    case directoryCreationFailed
    case noteNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "Failed to encode note data."
        case let .writeFailed(detail):
            "Failed to write note: \(detail)"
        case let .readFailed(detail):
            "Failed to read notes: \(detail)"
        case .directoryCreationFailed:
            "Failed to create storage directory."
        case let .noteNotFound(id):
            "Note \(id) not found on disk."
        }
    }
}

// MARK: - Schema Envelope (v1)

/// Wraps a `VoiceNote` with a version tag for future migrations.
private struct NoteEnvelope: Codable {
    let version: Int
    let note: VoiceNote

    init(note: VoiceNote) {
        self.version = 1
        self.note = note
    }
}

// MARK: - Legacy Migration

/// Decodes the pre-hardening format that stored an absolute `audioURL`.
private struct LegacyNoteEntity: Codable {
    let id: UUID
    let createdAt: Date
    var title: String
    let audioURL: URL
    let duration: TimeInterval
    let transcription: Transcription?
    let insights: Insights?
    var isFavorite: Bool

    func toVoiceNote() -> VoiceNote {
        VoiceNote(
            id: id,
            createdAt: createdAt,
            title: title,
            audioFilename: audioURL.lastPathComponent,
            duration: duration,
            transcription: transcription,
            insights: insights,
            isFavorite: isFavorite
        )
    }
}

// MARK: - Live Implementation

extension PersistenceClient: DependencyKey {
    public static let liveValue: PersistenceClient = {
        // nonisolated(unsafe): FileManager.default is a thread-safe singleton.
        nonisolated(unsafe) let fileManager = FileManager.default
        let logger = Logger(subsystem: "me.yasirromaya.whisp", category: "Persistence")

        let notesDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Notes", isDirectory: true)
        let audioDir = VoiceNote.audioDirectory

        // Create directories once at init with encryption
        do {
            try fileManager.createDirectory(at: notesDir, withIntermediateDirectories: true, attributes: [
                .protectionKey: FileProtectionType.complete,
            ])
            try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true, attributes: [
                .protectionKey: FileProtectionType.complete,
            ])
        } catch {
            logger.error("Failed to create storage directories: \(error.localizedDescription)")
        }

        // Shared write closure — atomic + file protection
        // Creates a fresh JSONEncoder per call to avoid thread-safety issues
        // with shared mutable encoder state.
        let writeNote: @Sendable (VoiceNote) throws -> Void = { note in
            let encoder = JSONEncoder()
            let envelope = NoteEnvelope(note: note)
            let data: Data
            do {
                data = try encoder.encode(envelope)
            } catch {
                logger.error("Encoding failed for note \(note.id): \(error.localizedDescription)")
                throw PersistenceError.encodingFailed
            }
            let url = notesDir.appendingPathComponent("\(note.id.uuidString).json")
            do {
                try data.write(to: url, options: [.atomic, .completeFileProtection])
            } catch {
                logger.error("Write failed for note \(note.id): \(error.localizedDescription)")
                throw PersistenceError.writeFailed(error.localizedDescription)
            }
            // Also protect the audio file if it exists
            let audioURL = note.audioURL
            if fileManager.fileExists(atPath: audioURL.path) {
                do {
                    try fileManager.setAttributes(
                        [.protectionKey: FileProtectionType.complete],
                        ofItemAtPath: audioURL.path
                    )
                } catch {
                    logger.warning("Failed to set audio file protection for \(note.id): \(error.localizedDescription)")
                }
            }
        }

        let tagsURL = notesDir.appendingPathComponent("tags.json")

        return PersistenceClient(
            saveNote: { note in
                try writeNote(note)
            },
            loadNotes: {
                let decoder = JSONDecoder()
                let files: [URL]
                do {
                    files = try fileManager.contentsOfDirectory(at: notesDir, includingPropertiesForKeys: nil)
                        .filter { $0.pathExtension == "json" && $0.lastPathComponent != "tags.json" }
                } catch {
                    logger.error("Failed to list notes directory: \(error.localizedDescription)")
                    throw PersistenceError.readFailed(error.localizedDescription)
                }

                var notes: [VoiceNote] = []
                for fileURL in files {
                    guard let data = try? Data(contentsOf: fileURL) else {
                        logger.warning("Corrupt file skipped: \(fileURL.lastPathComponent)")
                        continue
                    }

                    // Try new envelope format first
                    if let envelope = try? decoder.decode(NoteEnvelope.self, from: data) {
                        notes.append(envelope.note)
                        continue
                    }

                    // Fall back to legacy format
                    if let legacy = try? decoder.decode(LegacyNoteEntity.self, from: data) {
                        let migrated = legacy.toVoiceNote()
                        logger.info("Migrated legacy note \(migrated.id)")
                        // Write-back migration: re-save in new envelope format
                        do {
                            try writeNote(migrated)
                        } catch {
                            logger.warning("Write-back migration failed for \(migrated.id): \(error.localizedDescription)")
                        }
                        notes.append(migrated)
                        continue
                    }

                    logger.warning("Unreadable note file skipped: \(fileURL.lastPathComponent)")
                }

                return notes.sorted { $0.createdAt > $1.createdAt }
            },
            deleteNote: { note in
                let url = notesDir.appendingPathComponent("\(note.id.uuidString).json")
                try fileManager.removeItem(at: url)
                let audioURL = note.audioURL
                do {
                    try fileManager.removeItem(at: audioURL)
                } catch {
                    logger.warning("Audio file removal failed for \(note.id): \(error.localizedDescription)")
                }
            },
            updateNote: { note in
                try writeNote(note)
            },
            cleanupOrphanedAudio: {
                let decoder = JSONDecoder()
                let oneHourAgo = Date().addingTimeInterval(-3600)
                var removed = 0

                // Collect audio filenames referenced by saved notes
                let noteFiles = (try? fileManager.contentsOfDirectory(at: notesDir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" }) ?? []
                var referencedAudioFilenames: Set<String> = []
                for file in noteFiles {
                    guard let data = try? Data(contentsOf: file),
                          let envelope = try? decoder.decode(NoteEnvelope.self, from: data) else { continue }
                    referencedAudioFilenames.insert(envelope.note.audioFilename)
                }

                // Find and delete orphaned audio files older than 1 hour
                let audioFiles = (try? fileManager.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: [.creationDateKey])
                    .filter { $0.pathExtension == "m4a" }) ?? []
                for audioFile in audioFiles {
                    let filename = audioFile.lastPathComponent
                    guard !referencedAudioFilenames.contains(filename) else { continue }
                    // Safety: only delete files older than 1 hour
                    if let attrs = try? fileManager.attributesOfItem(atPath: audioFile.path),
                       let created = attrs[.creationDate] as? Date,
                       created < oneHourAgo {
                        do {
                            try fileManager.removeItem(at: audioFile)
                            removed += 1
                            logger.info("Cleaned up orphaned audio: \(filename)")
                        } catch {
                            logger.warning("Failed to clean up \(filename): \(error.localizedDescription)")
                        }
                    }
                }
                return removed
            },
            saveTags: { tags in
                let encoder = JSONEncoder()
                let data: Data
                do {
                    data = try encoder.encode(tags)
                } catch {
                    logger.error("Encoding tags failed: \(error.localizedDescription)")
                    throw PersistenceError.encodingFailed
                }
                do {
                    try data.write(to: tagsURL, options: [.atomic, .completeFileProtection])
                } catch {
                    logger.error("Write tags failed: \(error.localizedDescription)")
                    throw PersistenceError.writeFailed(error.localizedDescription)
                }
            },
            loadTags: {
                let decoder = JSONDecoder()
                guard fileManager.fileExists(atPath: tagsURL.path) else { return [] }
                let data = try Data(contentsOf: tagsURL)
                return try decoder.decode([Tag].self, from: data)
            }
        )
    }()

    public static let testValue = PersistenceClient(
        saveNote: { _ in },
        loadNotes: { [] },
        deleteNote: { _ in },
        updateNote: { _ in },
        cleanupOrphanedAudio: { 0 },
        saveTags: { _ in },
        loadTags: { [] }
    )

    #if DEBUG
    /// Screenshot mode persistence with realistic mock data (DEBUG only)
    public static let screenshotValue: PersistenceClient = {
        let (mockNotes, mockTags) = createScreenshotMockData()
        return PersistenceClient(
            saveNote: { _ in },
            loadNotes: { mockNotes },
            deleteNote: { _ in },
            updateNote: { _ in },
            cleanupOrphanedAudio: { 0 },
            saveTags: { _ in },
            loadTags: { mockTags }
        )
    }()
    #endif
}

// MARK: - Screenshot Mock Data (DEBUG only)

#if DEBUG
private func createScreenshotMockData() -> ([VoiceNote], [Tag]) {
    let calendar = Calendar.current
    let now = Date()

    // Tags
    let tagWork = Tag(id: UUID(), name: "Work", color: .blue)
    let tagPersonal = Tag(id: UUID(), name: "Personal", color: .green)
    let tagIdeas = Tag(id: UUID(), name: "Ideas", color: .purple)
    let tagUrgent = Tag(id: UUID(), name: "Urgent", color: .red)
    let tagHealth = Tag(id: UUID(), name: "Health", color: .teal)
    let tags = [tagWork, tagPersonal, tagIdeas, tagUrgent, tagHealth]

    // 1. Product launch meeting — multi-speaker, favorited, work + urgent
    let note1 = VoiceNote(
        id: UUID(),
        createdAt: calendar.date(byAdding: .hour, value: -2, to: now)!,
        title: "Product launch planning...",
        audioFilename: "mock-meeting.m4a",
        duration: 847,
        transcription: Transcription(
            text: "Let's discuss the product launch timeline. We need to finalize the marketing materials by next Friday. Sarah will handle the press release, and Mike will coordinate with the design team. The launch event is scheduled for March 15th at the downtown venue. We should also prepare a backup plan in case of any delays. Remember to send the investor update by end of day tomorrow.",
            speakerTurns: [
                SpeakerTurn(speakerLabel: "Speaker 1", text: "Let's discuss the product launch timeline. We need to finalize the marketing materials by next Friday.", startTime: 0, endTime: 8.5),
                SpeakerTurn(speakerLabel: "Speaker 2", text: "Sarah will handle the press release, and Mike will coordinate with the design team.", startTime: 12.0, endTime: 18.3),
                SpeakerTurn(speakerLabel: "Speaker 1", text: "The launch event is scheduled for March 15th at the downtown venue. We should also prepare a backup plan in case of any delays.", startTime: 22.0, endTime: 31.5),
                SpeakerTurn(speakerLabel: "Speaker 3", text: "Remember to send the investor update by end of day tomorrow.", startTime: 35.0, endTime: 40.2),
            ]
        ),
        insights: Insights(
            summary: "Product launch planning meeting covering timeline, responsibilities, and key deliverables for the upcoming March 15th launch event.",
            actionItems: [
                ActionItem(text: "Finalize marketing materials by Friday"),
                ActionItem(text: "Prepare press release (Sarah)"),
                ActionItem(text: "Coordinate with design team (Mike)"),
                ActionItem(text: "Send investor update by tomorrow EOD"),
            ],
            events: [
                ExtractedEvent(
                    title: "Product Launch Event",
                    date: calendar.date(byAdding: .day, value: 38, to: now),
                    rawDateText: "March 15th at downtown venue"
                ),
                ExtractedEvent(
                    title: "Marketing Materials Deadline",
                    date: calendar.date(byAdding: .day, value: 5, to: now),
                    rawDateText: "next Friday"
                ),
            ],
            keyPoints: [
                "Launch scheduled for March 15th",
                "Marketing materials deadline: next Friday",
                "Backup plan needed for potential delays",
                "Investor update due tomorrow",
            ]
        ),
        isFavorite: true,
        tagIDs: [tagWork.id, tagUrgent.id]
    )

    // 2. Doctor appointment follow-up — personal + health
    let note2 = VoiceNote(
        id: UUID(),
        createdAt: calendar.date(byAdding: .hour, value: -5, to: now)!,
        title: "Doctor said to reduce caffeine...",
        audioFilename: "mock-health.m4a",
        duration: 94,
        transcription: Transcription(
            text: "Doctor said to reduce caffeine intake to one cup per day. Need to schedule a follow-up blood test in two weeks. Also should start taking vitamin D supplements daily. Blood pressure was slightly elevated at 135 over 85."
        ),
        insights: Insights(
            summary: "Doctor visit follow-up notes: reduce caffeine, schedule blood test, start vitamin D.",
            actionItems: [
                ActionItem(text: "Reduce caffeine to one cup per day"),
                ActionItem(text: "Schedule follow-up blood test"),
                ActionItem(text: "Start taking vitamin D supplements daily"),
            ],
            events: [
                ExtractedEvent(
                    title: "Follow-up Blood Test",
                    date: calendar.date(byAdding: .day, value: 14, to: now),
                    rawDateText: "in two weeks"
                ),
            ],
            keyPoints: [
                "Blood pressure slightly elevated: 135/85",
                "Vitamin D supplements recommended",
            ]
        ),
        isFavorite: false,
        tagIDs: [tagPersonal.id, tagHealth.id]
    )

    // 3. Weekend app idea — ideas tag
    let note3 = VoiceNote(
        id: UUID(),
        createdAt: calendar.date(byAdding: .day, value: -1, to: now)!,
        title: "App ideas for weekend...",
        audioFilename: "mock-ideas.m4a",
        duration: 156,
        transcription: Transcription(
            text: "Quick idea for the weekend project. Build a habit tracker that uses AI to suggest optimal times based on your calendar. Could integrate with Apple Health for sleep data. Would need a clean SwiftUI interface with charts."
        ),
        insights: Insights(
            summary: "Brainstorm for a weekend project: AI-powered habit tracker with calendar and health integrations.",
            actionItems: [
                ActionItem(text: "Research Apple Health API"),
                ActionItem(text: "Sketch UI wireframes"),
            ],
            events: [],
            keyPoints: [
                "AI-powered habit tracking",
                "Calendar integration for optimal timing",
                "Apple Health integration for sleep data",
            ]
        ),
        isFavorite: true,
        tagIDs: [tagIdeas.id]
    )

    // 4. Quick grocery reminder — personal, no tags
    let note4 = VoiceNote(
        id: UUID(),
        createdAt: calendar.date(byAdding: .hour, value: -6, to: now)!,
        title: "Pick up groceries after...",
        audioFilename: "mock-reminder.m4a",
        duration: 23,
        transcription: Transcription(
            text: "Pick up groceries after work. Need milk, eggs, bread, and avocados for the weekend."
        ),
        insights: Insights(
            summary: "Grocery shopping reminder.",
            actionItems: [
                ActionItem(text: "Buy milk, eggs, bread, avocados"),
            ],
            events: [],
            keyPoints: [
                "Shopping needed after work",
            ]
        ),
        isFavorite: false,
        tagIDs: [tagPersonal.id]
    )

    // 5. Client call with two speakers — work tag
    let note5 = VoiceNote(
        id: UUID(),
        createdAt: calendar.date(byAdding: .day, value: -2, to: now)!,
        title: "Client feedback on prototype...",
        audioFilename: "mock-client.m4a",
        duration: 423,
        transcription: Transcription(
            text: "The client loved the new onboarding flow but wants to simplify the payment screen. They need the updated mockups by Wednesday. Also mentioned budget approval for phase two is expected next month.",
            speakerTurns: [
                SpeakerTurn(speakerLabel: "Speaker 1", text: "The client loved the new onboarding flow but wants to simplify the payment screen.", startTime: 0, endTime: 6.5),
                SpeakerTurn(speakerLabel: "Speaker 2", text: "They need the updated mockups by Wednesday. Also mentioned budget approval for phase two is expected next month.", startTime: 10.0, endTime: 18.0),
            ]
        ),
        insights: Insights(
            summary: "Client feedback: positive on onboarding, requests simpler payment screen and updated mockups by Wednesday.",
            actionItems: [
                ActionItem(text: "Simplify payment screen design"),
                ActionItem(text: "Send updated mockups by Wednesday"),
            ],
            events: [
                ExtractedEvent(
                    title: "Mockup Delivery Deadline",
                    date: calendar.date(byAdding: .day, value: 3, to: now),
                    rawDateText: "Wednesday"
                ),
            ],
            keyPoints: [
                "Client approved new onboarding flow",
                "Phase two budget expected next month",
            ]
        ),
        isFavorite: false,
        tagIDs: [tagWork.id]
    )

    return ([note1, note2, note3, note4, note5], tags)
}
#endif

public extension DependencyValues {
    var persistence: PersistenceClient {
        get { self[PersistenceClient.self] }
        set { self[PersistenceClient.self] = newValue }
    }
}
