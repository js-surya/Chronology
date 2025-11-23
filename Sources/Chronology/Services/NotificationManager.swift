import Foundation
import UserNotifications
import AppKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    private var useLegacyNotifications = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if granted {
                    print("✅ Notification permission granted")
                } else {
                    print("❌ Notification permission denied")
                    if let error = error {
                        print("Error: \(error.localizedDescription)")
                    }
                }
                completion?(granted)
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func sendTestNotification(completion: ((Bool, String) -> Void)? = nil) {
        checkAuthorizationStatus()
        
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            print("Notification authorization status: \(settings.authorizationStatus.rawValue)")
            print("Alert setting: \(settings.alertSetting.rawValue)")
            
            // If not authorized, try using NSUserNotification as fallback
            if settings.authorizationStatus != .authorized {
                DispatchQueue.main.async {
                    self?.sendLegacyNotification(title: "🎉 Chronology Test", body: "Notifications are working correctly!")
                    completion?(true, "Test notification sent using legacy system!")
                }
                return
            }
            
            let content = UNMutableNotificationContent()
            content.title = "🎉 Chronology Test"
            content.body = "Notifications are working correctly!"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to schedule notification: \(error.localizedDescription)")
                        // Fallback to legacy notifications
                        self?.sendLegacyNotification(title: "🎉 Chronology Test", body: "Notifications are working correctly!")
                        completion?(true, "Test notification sent using legacy system!")
                    } else {
                        print("✅ Test notification scheduled successfully")
                        completion?(true, "Test notification sent! Check in 1 second.")
                    }
                }
            }
        }
    }
    
    private func sendLegacyNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.deliveryDate = Date()
        
        // Force notification to display as banner even if app is active
        notification.hasActionButton = false
        
        NSUserNotificationCenter.default.deliver(notification)
        print("✅ Legacy notification delivered")
    }
    
    func scheduleNotifications(for events: [Event], minutesBefore: Int) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            // For self-signed apps, we'll use legacy notifications as fallback
            let useLegacy = settings.authorizationStatus != .authorized
            
            if useLegacy {
                print("⚠️ Using legacy notification system for event reminders")
                self?.scheduleLegacyNotifications(for: events, minutesBefore: minutesBefore)
                return
            }
            
            var scheduledCount = 0
            for event in events {
                if event.startTime > Date() {
                    let content = UNMutableNotificationContent()
                    content.title = "\(event.title) starting in \(minutesBefore) min"
                    content.body = "Grab a cup of ☕︎ and head to \(event.location)"
                    content.sound = .default
                    
                    guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: event.startTime),
                          triggerDate > Date() else { continue }
                    
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    
                    let request = UNNotificationRequest(identifier: "event-\(event.id)", content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request) { error in
                        if error == nil {
                            scheduledCount += 1
                        }
                    }
                }
            }
            print("✅ Scheduled \(scheduledCount) event notifications")
        }
    }
    
    private func scheduleLegacyNotifications(for events: [Event], minutesBefore: Int) {
        // For legacy notifications, we'll need to use a timer-based approach
        // This is a simplified version - in production you'd want to persist these
        var scheduledCount = 0
        
        for event in events {
            guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: event.startTime),
                  triggerDate > Date() else { continue }
            
            let timeInterval = triggerDate.timeIntervalSinceNow
            
            Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
                let notification = NSUserNotification()
                notification.title = "\(event.title) starting in \(minutesBefore) min"
                notification.informativeText = "Grab a cup of ☕︎ and head to \(event.location)"
                notification.soundName = NSUserNotificationDefaultSoundName
                notification.deliveryDate = Date()
                notification.hasActionButton = false
                
                NSUserNotificationCenter.default.deliver(notification)
            }
            scheduledCount += 1
        }
        
        print("✅ Scheduled \(scheduledCount) legacy event notifications")
    }
    
    func scheduleImportantReminders(for events: [Event], importantEvents: [ImportantEvent]) {
        // Schedule important event reminders
        for importantEvent in importantEvents {
            // Find matching event
            guard let event = events.first(where: { $0.title == importantEvent.eventTitle && Calendar.current.isDate($0.startTime, inSameDayAs: importantEvent.eventDate) }),
                  event.startTime > Date() else { continue }
            
            guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -importantEvent.reminderMinutes, to: event.startTime),
                  triggerDate > Date() else { continue }
            
            // Try modern notification first
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                if settings.authorizationStatus == .authorized {
                    let content = UNMutableNotificationContent()
                    content.title = "⚠️ Important: \(event.title)"
                    content.body = "This event starts in \(importantEvent.reminderMinutes) minutes at \(event.location). Don't miss it!"
                    content.sound = UNNotificationSound.defaultCritical
                    
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    
                    let request = UNNotificationRequest(identifier: "important-\(event.id)", content: content, trigger: trigger)
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("❌ Failed to schedule important reminder: \(error.localizedDescription)")
                        } else {
                            print("✅ Important reminder scheduled for \(event.title)")
                        }
                    }
                }
            }
            
            // Also schedule legacy notification as fallback
            let timeInterval = triggerDate.timeIntervalSinceNow
            if timeInterval > 0 {
                Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
                    let notification = NSUserNotification()
                    notification.title = "⚠️ Important: \(importantEvent.eventTitle)"
                    notification.informativeText = "This event starts in \(importantEvent.reminderMinutes) minutes at \(event.location). Don't miss it!"
                    notification.soundName = NSUserNotificationDefaultSoundName
                    notification.deliveryDate = Date()
                    notification.hasActionButton = false
                    
                    NSUserNotificationCenter.default.deliver(notification)
                }
                print("✅ Legacy important reminder scheduled for \(event.title)")
            }
        }
    }
}
