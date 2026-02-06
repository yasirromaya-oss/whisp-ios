import Dependencies
import Foundation
import NaturalLanguage
import os
import Speech

import FoundationModels

public struct TranscriptionClient: Sendable {
    public var transcribe: @Sendable (URL) async throws -> Transcription
    public var extractInsights: @Sendable (String) async throws -> Insights
    public var requestSpeechAuthorization: @Sendable () async -> Bool
}

extension TranscriptionClient: DependencyKey {
    public static let liveValue = TranscriptionClient(
        transcribe: { try await SpeechTranscriber.transcribe(url: $0) },
        extractInsights: { try await InsightExtractor.extract(from: $0) },
        requestSpeechAuthorization: {
            await SpeechTranscriber.requestAuthorization() == .authorized
        }
    )

    public static let testValue = TranscriptionClient(
        transcribe: { _ in Transcription(text: "") },
        extractInsights: { _ in Insights() },
        requestSpeechAuthorization: { true }
    )
}

public extension DependencyValues {
    var transcription: TranscriptionClient {
        get { self[TranscriptionClient.self] }
        set { self[TranscriptionClient.self] = newValue }
    }
}

// MARK: - Speech Transcription

private enum SpeechTranscriber {
    static func transcribe(url: URL) async throws -> Transcription {
        guard !ProcessInfo.processInfo.isiOSAppOnMac else {
            throw TranscriptionError.unavailable
        }

        let status = await requestAuthorization()
        guard status == .authorized else {
            throw TranscriptionError.from(status)
        }

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false

        let box = RecognitionBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                box.start(recognizer: recognizer, request: request, continuation: continuation)
            }
        } onCancel: {
            box.cancel()
        }
    }

    static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

/// Bridges callback-based SFSpeechRecognitionTask with structured concurrency.
/// @unchecked Sendable: All mutable state protected by `lock`.
///
/// Thread-safety invariant: The continuation is resumed exactly once.
/// Three paths can resume it — `handleResult` (final result or error),
/// `timeout`, and `cancel`. Each atomically checks `isResumed` under the lock
/// and only the first one to set it `true` extracts the continuation and
/// resumes it outside the lock.
private final class RecognitionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<Transcription, Error>?
    private var isResumed = false
    private var lastText = ""
    private var lastSegments: [TranscriptionSegment] = []
    private var timeoutTask: Task<Void, Never>?

    deinit {
        recognitionTask?.cancel()
        timeoutTask?.cancel()
    }

    /// Ordering: continuation is stored BEFORE creating the recognition task
    /// because the callback may fire synchronously. The recognitionTask is stored
    /// after creation. If cancel() races with start(), it may find recognitionTask
    /// nil — but cancel() always resumes the continuation, so the caller won't hang.
    /// The orphaned task will complete on its own (harmless).
    func start(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechURLRecognitionRequest,
        continuation: CheckedContinuation<Transcription, Error>
    ) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()

        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handleResult(result: result, error: error)
        }

        lock.lock()
        recognitionTask = task
        lock.unlock()

        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            self?.timeout()
        }
    }

    /// Called by withTaskCancellationHandler when TCA cancels the effect.
    func cancel() {
        lock.lock()
        guard !isResumed else {
            lock.unlock()
            return
        }
        isResumed = true
        timeoutTask?.cancel()
        let task = recognitionTask
        let cont = continuation
        continuation = nil
        lock.unlock()

        // Cancel outside the lock to avoid deadlock
        task?.cancel()
        cont?.resume(throwing: CancellationError())
    }

    private func handleResult(result: SFSpeechRecognitionResult?, error: Error?) {
        lock.lock()
        guard !isResumed else {
            lock.unlock()
            return
        }

        if let error {
            isResumed = true
            timeoutTask?.cancel()
            let text = lastText
            let segments = lastSegments
            let cont = continuation
            continuation = nil
            lock.unlock()

            if !text.isEmpty {
                let speakerTurns = SpeakerDetector.detect(from: segments)
                cont?.resume(returning: Transcription(text: text, segments: segments, speakerTurns: speakerTurns))
            } else {
                cont?.resume(throwing: TranscriptionError.failed(error.localizedDescription))
            }
            return
        }

        guard let result else {
            isResumed = true
            timeoutTask?.cancel()
            let cont = continuation
            continuation = nil
            lock.unlock()
            cont?.resume(throwing: TranscriptionError.noResult)
            return
        }

        let text = result.bestTranscription.formattedString
        if !text.isEmpty { lastText = text }

        // Extract segments from the best transcription
        let sfSegments = result.bestTranscription.segments
        lastSegments = sfSegments.map { seg in
            TranscriptionSegment(
                text: seg.substring,
                timestamp: seg.timestamp,
                duration: seg.duration,
                confidence: seg.confidence
            )
        }

        if result.isFinal {
            isResumed = true
            timeoutTask?.cancel()
            let finalText = lastText
            let finalSegments = lastSegments
            let cont = continuation
            continuation = nil
            lock.unlock()
            let speakerTurns = SpeakerDetector.detect(from: finalSegments)
            cont?.resume(returning: Transcription(text: finalText, segments: finalSegments, speakerTurns: speakerTurns))
        } else {
            lock.unlock()
        }
    }

    private func timeout() {
        lock.lock()
        guard !isResumed else {
            lock.unlock()
            return
        }
        isResumed = true
        let text = lastText
        let segments = lastSegments
        let task = recognitionTask
        let cont = continuation
        continuation = nil
        lock.unlock()

        // Cancel outside the lock to avoid deadlock
        task?.cancel()
        let speakerTurns = SpeakerDetector.detect(from: segments)
        cont?.resume(returning: Transcription(text: text, segments: segments, speakerTurns: speakerTurns))
    }
}

// MARK: - Speaker Detection

/// Heuristic pause-based speaker turn detection.
/// Groups consecutive segments into utterances, then marks speaker changes
/// when silence gaps exceed the speaker change threshold.
enum SpeakerDetector {
    private static let utteranceGapThreshold: TimeInterval = 1.2
    private static let speakerChangeThreshold: TimeInterval = 3.0
    private static let maxSpeakers = 6

    static func detect(from segments: [TranscriptionSegment]) -> [SpeakerTurn] {
        guard !segments.isEmpty else { return [] }

        // Group segments into utterances (runs with small gaps)
        var utterances: [[TranscriptionSegment]] = []
        var currentUtterance: [TranscriptionSegment] = [segments[0]]

        for i in 1..<segments.count {
            let prev = segments[i - 1]
            let curr = segments[i]
            let gap = curr.timestamp - (prev.timestamp + prev.duration)

            if gap > utteranceGapThreshold {
                utterances.append(currentUtterance)
                currentUtterance = [curr]
            } else {
                currentUtterance.append(curr)
            }
        }
        utterances.append(currentUtterance)

        // Assign speaker labels based on gaps between utterances
        var turns: [SpeakerTurn] = []
        var currentSpeakerIndex = 0

        for (i, utterance) in utterances.enumerated() {
            if i > 0 {
                let prevUtterance = utterances[i - 1]
                let prevEnd = prevUtterance.last!.timestamp + prevUtterance.last!.duration
                let currStart = utterance.first!.timestamp
                let gap = currStart - prevEnd

                if gap >= speakerChangeThreshold {
                    currentSpeakerIndex = (currentSpeakerIndex + 1) % maxSpeakers
                }
            }

            let text = utterance.map(\.text).joined(separator: " ")
            let startTime = utterance.first!.timestamp
            let lastSeg = utterance.last!
            let endTime = lastSeg.timestamp + lastSeg.duration

            turns.append(SpeakerTurn(
                speakerLabel: L10nKit.speaker(currentSpeakerIndex + 1),
                text: text,
                startTime: startTime,
                endTime: endTime
            ))
        }

        return turns
    }
}

// MARK: - Insight Extraction

private let insightLogger = Logger(subsystem: "me.yasirromaya.whisp.kit", category: "InsightExtractor")

private enum InsightExtractor {
    static func extract(from text: String) async throws -> Insights {
        let ruleBased = ruleBasedExtract(from: text)
        do {
            let enhanced = try await extractWithFoundationModels(text: text, fallback: ruleBased)
            return enhanced
        } catch {
            return ruleBased
        }
    }

    // MARK: - Rule-Based Extraction

    private static func ruleBasedExtract(from text: String) -> Insights {
        let sentences = splitSentences(text)
        guard !sentences.isEmpty else {
            return Insights(summary: text.isEmpty ? nil : text)
        }

        // Summary: first 1-2 sentences
        let summaryCount = sentences.count == 1 ? 1 : 2
        let summary = sentences.prefix(summaryCount).joined(separator: " ")

        // Action items: sentences matching action patterns
        let actionPatterns: [String] = [
            "need to", "should", "must", "have to", "going to",
            "remember to", "don't forget", "make sure",
            "todo", "to-do", "action item",
        ]
        var actionSentenceIndices = Set<Int>()
        var actionItems: [ActionItem] = []
        for (index, sentence) in sentences.enumerated() {
            let lower = sentence.lowercased()
            if actionPatterns.contains(where: { lower.contains($0) }) ||
                lower.range(of: #"\bwill\s+\w+"#, options: .regularExpression) != nil {
                actionSentenceIndices.insert(index)
                actionItems.append(ActionItem(text: sentence.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }

        // Events: NSDataDetector for dates
        var eventSentenceIndices = Set<Int>()
        let events = extractEvents(from: text, sentences: sentences, eventSentenceIndices: &eventSentenceIndices)

        // Key points: remaining substantive sentences
        let usedIndices = actionSentenceIndices.union(eventSentenceIndices)
        let keyPoints = sentences.enumerated()
            .filter { !usedIndices.contains($0.offset) && $0.element.count > 20 }
            .prefix(5)
            .map { $0.element.trimmingCharacters(in: .whitespacesAndNewlines) }

        return Insights(
            summary: summary,
            actionItems: actionItems,
            events: events,
            keyPoints: Array(keyPoints)
        )
    }

    private static func splitSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }

    private static func extractEvents(
        from text: String,
        sentences: [String],
        eventSentenceIndices: inout Set<Int>
    ) -> [ExtractedEvent] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return []
        }

        let nsText = text as NSString
        let matches = detector.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var events: [ExtractedEvent] = []
        var seenDateTexts = Set<String>()

        for match in matches {
            let matchedText = nsText.substring(with: match.range)
            guard !seenDateTexts.contains(matchedText.lowercased()) else { continue }
            seenDateTexts.insert(matchedText.lowercased())

            // Find the containing sentence
            let matchRange = Range(match.range, in: text)!
            var containingSentence = text
            for (index, sentence) in sentences.enumerated() {
                if let sentenceRange = text.range(of: sentence),
                   sentenceRange.overlaps(matchRange) {
                    containingSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    eventSentenceIndices.insert(index)
                    break
                }
            }

            events.append(ExtractedEvent(
                title: containingSentence,
                date: match.date,
                rawDateText: matchedText
            ))
        }

        return events
    }

    // MARK: - FoundationModels Enhancement

    private static func extractWithFoundationModels(text: String, fallback: Insights) async throws -> Insights {
        let session = LanguageModelSession(instructions: """
        Extract structured insights from voice note transcripts.
        Respond EXACTLY in this format with section markers on their own lines:

        SUMMARY:
        (1-2 sentence summary)

        ACTION_ITEMS:
        - item one
        - item two

        EVENTS:
        - event title | date text
        - event title | date text

        KEY_POINTS:
        - point one
        - point two

        If a section has no items, write NONE after the marker.
        """)

        do {
            try await session.prewarm()
        } catch {
            insightLogger.warning("FoundationModels prewarm failed: \(error.localizedDescription)")
        }

        // Structured task group: generation races against a 30s timeout.
        // If the parent task is cancelled, both children are automatically cancelled.
        let content: String = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                let response = try await session.respond(to: """
                Extract insights from this transcript:

                \(text)
                """)
                return response.content
            }
            group.addTask {
                try await Task.sleep(for: .seconds(30))
                throw TranscriptionError.unavailable
            }
            guard let result = try await group.next() else {
                throw TranscriptionError.unavailable
            }
            group.cancelAll()
            return result
        }

        return parseSectionedResponse(content, fallback: fallback, originalText: text)
    }

    private static func parseSectionedResponse(_ content: String, fallback: Insights, originalText: String) -> Insights {
        let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        var currentSection = ""
        var summary: String?
        var actionItems: [ActionItem] = []
        var events: [ExtractedEvent] = []
        var keyPoints: [String] = []
        var summaryLines: [String] = []

        for line in lines {
            let upper = line.uppercased()
            if upper.hasPrefix("SUMMARY:") {
                currentSection = "SUMMARY"
                let rest = line.dropFirst("SUMMARY:".count).trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty && rest.uppercased() != "NONE" { summaryLines.append(rest) }
                continue
            } else if upper.hasPrefix("ACTION_ITEMS:") || upper.hasPrefix("ACTION ITEMS:") {
                currentSection = "ACTION_ITEMS"
                continue
            } else if upper.hasPrefix("EVENTS:") {
                currentSection = "EVENTS"
                continue
            } else if upper.hasPrefix("KEY_POINTS:") || upper.hasPrefix("KEY POINTS:") {
                currentSection = "KEY_POINTS"
                continue
            }

            guard !line.isEmpty, line.uppercased() != "NONE" else { continue }

            let cleaned = line.drop(while: { "-* ".contains($0) }).trimmingCharacters(in: .whitespaces)
            guard !cleaned.isEmpty else { continue }

            switch currentSection {
            case "SUMMARY":
                summaryLines.append(cleaned)
            case "ACTION_ITEMS":
                actionItems.append(ActionItem(text: cleaned))
            case "EVENTS":
                let parts = cleaned.components(separatedBy: "|")
                let title = parts[0].trimmingCharacters(in: .whitespaces)
                let rawDateText = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
                // Validate date with NSDataDetector
                let date = detectDate(in: rawDateText.isEmpty ? title : rawDateText)
                events.append(ExtractedEvent(title: title, date: date, rawDateText: rawDateText))
            case "KEY_POINTS":
                keyPoints.append(cleaned)
            default:
                break
            }
        }

        if !summaryLines.isEmpty {
            summary = summaryLines.joined(separator: " ")
        }

        // Merge: use LLM results if non-empty, otherwise fall back to rule-based
        return Insights(
            summary: summary ?? fallback.summary,
            actionItems: actionItems.isEmpty ? fallback.actionItems : actionItems,
            events: events.isEmpty ? fallback.events : events,
            keyPoints: keyPoints.isEmpty ? fallback.keyPoints : keyPoints
        )
    }

    private static func detectDate(in text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let nsText = text as NSString
        let match = detector.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length))
        return match?.date
    }
}

// MARK: - Errors

public enum TranscriptionError: LocalizedError {
    case unauthorized
    case denied
    case restricted
    case unavailable
    case noResult
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            L10nKit.errorUnauthorized
        case .denied:
            L10nKit.errorDenied
        case .restricted:
            L10nKit.errorRestricted
        case .unavailable:
            L10nKit.errorUnavailable
        case .noResult:
            L10nKit.errorNoResult
        case let .failed(message):
            message
        }
    }

    static func from(_ status: SFSpeechRecognizerAuthorizationStatus) -> TranscriptionError {
        switch status {
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .unauthorized
        default: .unavailable
        }
    }
}
