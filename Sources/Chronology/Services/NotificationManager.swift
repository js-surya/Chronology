import Foundation
import UserNotifications
import AppKit

/// A reminder computed from the schedule, before it is handed to UNUserNotificationCenter.
struct PlannedNotification: Equatable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    /// macOS keeps at most 64 pending requests per app; leave headroom for the test notification.
    nonisolated static let maxPending = 60

    @Published var isAuthorized = false

    /// UNUserNotificationCenter traps when the process has no bundle (e.g. `swift run`, unit tests).
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    private init() {}

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        guard let center else { completion?(false); return }
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion?(granted)
            }
        }
    }

    func checkAuthorizationStatus() {
        guard let center else { return }
        center.getNotificationSettings { settings in
            let authorized = [.authorized, .provisional].contains(settings.authorizationStatus)
            DispatchQueue.main.async {
                self.isAuthorized = authorized
            }
        }
    }

    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    func sendTestNotification(completion: ((Bool, String) -> Void)? = nil) {
        guard let center else {
            completion?(false, "Notifications need the packaged Chronology.app.")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Chronology Test"
        content.body = "Notifications are working correctly!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "chronology.test", content: content, trigger: nil)
        center.add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    completion?(false, error.localizedDescription)
                } else {
                    completion?(true, "Test notification sent!")
                }
            }
        }
    }

    func cancelAll() {
        center?.removeAllPendingNotificationRequests()
    }

    /// Replaces every pending reminder with a fresh set, so repeated reloads never duplicate alerts.
    func reschedule(events: [Event], minutesBefore: Int, importantEvents: [ImportantEvent]) {
        guard let center else { return }
        let planned = Self.plan(events: events, minutesBefore: minutesBefore, importantEvents: importantEvents, now: Date())

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

    // MARK: - Planning

    /// Pure scheduling logic: future reminders for timed events plus important-event reminders,
    /// soonest first, capped at `maxPending`.
    nonisolated static func plan(events: [Event], minutesBefore: Int, importantEvents: [ImportantEvent], now: Date) -> [PlannedNotification] {
        var planned: [PlannedNotification] = []

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
            guard let event = events.first(where: {
                $0.title == important.eventTitle && abs($0.startTime.timeIntervalSince(important.eventDate)) < 60
            }) else { continue }
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

    nonisolated private static func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
