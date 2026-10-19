import Foundation
import UserNotifications
import AppKit
import ChronologyCore

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false

    private var center: UNUserNotificationCenter? { ReminderScheduler.center }
    
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
        ReminderScheduler.cancelAll()
    }
    
    /// Replaces every pending reminder with a fresh set, so repeated reloads never duplicate alerts.
    func reschedule(events: [Event], minutesBefore: Int, importantEvents: [ImportantEvent]) {
        ReminderScheduler.replacePending(with: NotificationPlanner.plan(
            events: events, minutesBefore: minutesBefore, importantEvents: importantEvents, now: Date()))
    }
}
