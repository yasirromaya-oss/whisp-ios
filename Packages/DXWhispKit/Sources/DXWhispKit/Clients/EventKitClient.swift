import Dependencies
import Foundation
import os

public struct EventKitClient: Sendable {
    public var requestRemindersAccess: @Sendable () async -> Bool
    public var addReminder: @Sendable (String, Date?) async throws -> Void
    public var requestCalendarAccess: @Sendable () async -> Bool
    public var addCalendarEvent: @Sendable (String, Date, String?) async throws -> Void

    public init(
        requestRemindersAccess: @escaping @Sendable () async -> Bool,
        addReminder: @escaping @Sendable (String, Date?) async throws -> Void,
        requestCalendarAccess: @escaping @Sendable () async -> Bool,
        addCalendarEvent: @escaping @Sendable (String, Date, String?) async throws -> Void
    ) {
        self.requestRemindersAccess = requestRemindersAccess
        self.addReminder = addReminder
        self.requestCalendarAccess = requestCalendarAccess
        self.addCalendarEvent = addCalendarEvent
    }
}

extension EventKitClient: DependencyKey {
    public static let liveValue: EventKitClient = {
        let live = LiveEventKitClient()
        return EventKitClient(
            requestRemindersAccess: { await live.requestRemindersAccess() },
            addReminder: { try await live.addReminder(title: $0, dueDate: $1) },
            requestCalendarAccess: { await live.requestCalendarAccess() },
            addCalendarEvent: { try await live.addCalendarEvent(title: $0, startDate: $1, notes: $2) }
        )
    }()

    public static let testValue = EventKitClient(
        requestRemindersAccess: { true },
        addReminder: { _, _ in },
        requestCalendarAccess: { true },
        addCalendarEvent: { _, _, _ in }
    )
}

public extension DependencyValues {
    var eventKit: EventKitClient {
        get { self[EventKitClient.self] }
        set { self[EventKitClient.self] = newValue }
    }
}

// MARK: - Live implementation (EventKit)

import EventKit

/// @unchecked Sendable: EKEventStore requires single-thread access;
/// all synchronous operations are serialized through `lock`.
private final class LiveEventKitClient: @unchecked Sendable {
    private static let logger = Logger(subsystem: "me.yasirromaya.whisp.kit", category: "EventKit")
    private let lock = NSLock()
    private let eventStore = EKEventStore()

    // Note: Permission methods are called without the lock because they are
    // async and the lock can't be held across await. Apple's permission APIs
    // present system-level UI and are safe to call from any thread. The lock
    // serializes only synchronous EKEventStore save/fetch operations.
    func requestRemindersAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToReminders()
        } catch {
            Self.logger.warning("Reminders access request failed: \(error.localizedDescription)")
            return false
        }
    }

    func addReminder(title: String, dueDate: Date?) async throws {
        try lock.withLock {
            let reminder = EKReminder(eventStore: eventStore)
            reminder.title = title
            if let due = dueDate {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: due
                )
            }
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
            try eventStore.save(reminder, commit: true)
        }
    }

    func requestCalendarAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            Self.logger.warning("Calendar access request failed: \(error.localizedDescription)")
            return false
        }
    }

    func addCalendarEvent(title: String, startDate: Date, notes: String?) async throws {
        try lock.withLock {
            let event = EKEvent(eventStore: eventStore)
            event.title = title
            event.startDate = startDate
            event.endDate = startDate.addingTimeInterval(3600)
            event.notes = notes
            event.calendar = eventStore.defaultCalendarForNewEvents
            try eventStore.save(event, span: .thisEvent)
        }
    }
}
