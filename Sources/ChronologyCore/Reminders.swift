import Foundation
import UserNotifications

/// A reminder computed from the schedule, before it is handed to UNUserNotificationCenter.
public struct PlannedNotification: Equatable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let fireDate: Date
}

public enum NotificationPlanner {
    /// Apple platforms keep at most 64 pending requests per app; leave headroom for a test notification.
    public static let maxPending = 60

    /// Future reminders for timed events plus important-event reminders, soonest first, capped at `maxPending`.
    /// `atStart` / `atEnd` add an alert when a class's countdown runs out (it starts, or it ends).
    public static func plan(events: [Event], minutesBefore: Int, importantEvents: [ImportantEvent], now: Date,
                            atStart: Bool = false, atEnd: Bool = false) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []

        for event in events where !event.isAllDay {
            let place = event.location.isEmpty ? "" : " · \(event.location)"
            if atStart, event.startTime > now {
                planned.append(PlannedNotification(
                    id: "start.\(event.id)",
                    title: "\(event.title) is starting",
                    body: "Now until \(timeString(event.endTime))\(place)",
                    fireDate: event.startTime
                ))
            }
            if atEnd, event.endTime > now {
                planned.append(PlannedNotification(
                    id: "end.\(event.id)",
                    title: "\(event.title) has ended",
                    body: "Class is over\(place).",
                    fireDate: event.endTime
                ))
            }
        }

        for event in events where !event.isAllDay {
            let fireDate = event.startTime.addingTimeInterval(-Double(minutesBefore) * 60)
            guard fireDate > now else { continue }
            planned.append(PlannedNotification(
                id: "event.\(event.id)",
                title: "\(event.title) starting in \(minutesBefore) min",
                body: event.location.isEmpty ? "Starts at \(timeString(event.startTime))" : "Head to \(event.location)",
                fireDate: fireDate
            ))
        }

        for important in importantEvents {
            guard let event = events.first(where: important.matches) else { continue }
            let fireDate = event.startTime.addingTimeInterval(-Double(important.reminderMinutes) * 60)
            guard fireDate > now else { continue }
            let place = event.location.isEmpty ? "" : " at \(event.location)"
            planned.append(PlannedNotification(
                id: "important.\(event.id)",
                title: "Important: \(event.title)",
                body: "Starts in \(important.reminderMinutes) minutes\(place). Don't miss it!",
                fireDate: fireDate
            ))
        }

        return Array(planned.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

public enum ReminderScheduler {
    /// UNUserNotificationCenter traps when the process has no bundle (e.g. `swift run`, unit tests).
    public static var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    /// Replaces every pending reminder with `planned`, so repeated reloads never duplicate alerts.
    public static func replacePending(with planned: [PlannedNotification]) {
        guard let center else { return }
        center.removeAllPendingNotificationRequests()
        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    public static func cancelAll() {
        center?.removeAllPendingNotificationRequests()
    }
}
