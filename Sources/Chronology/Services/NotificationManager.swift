import Foundation
import UserNotifications
import AppKit

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = true
    
    private init() {
        // Always consider authorized for legacy notifications
    }
    
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        // Legacy notifications don't need authorization
        DispatchQueue.main.async {
            self.isAuthorized = true
            completion?(true)
        }
    }
    
    func checkAuthorizationStatus() {
        // Legacy notifications are always authorized
        DispatchQueue.main.async {
            self.isAuthorized = true
        }
    }
    
    func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func sendTestNotification(completion: ((Bool, String) -> Void)? = nil) {
        let notification = NSUserNotification()
        notification.title = "🎉 Chronology Test"
        notification.informativeText = "Notifications are working correctly!"
        notification.soundName = NSUserNotificationDefaultSoundName
        notification.deliveryDate = Date()
        notification.hasActionButton = false
        
        NSUserNotificationCenter.default.deliver(notification)
        
        DispatchQueue.main.async {
            completion?(true, "Test notification sent!")
        }
    }
    

    
    func scheduleNotifications(for events: [Event], minutesBefore: Int) {
        // Cancel existing timers if any
        // Using Timer-based approach for legacy notifications
        var scheduledCount = 0
        
        for event in events {
            guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -minutesBefore, to: event.startTime),
                  triggerDate > Date() else { continue }
            
            let timeInterval = triggerDate.timeIntervalSinceNow
            
            Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
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
        
    }
    

    
    func scheduleImportantReminders(for events: [Event], importantEvents: [ImportantEvent]) {
        for importantEvent in importantEvents {
            guard let event = events.first(where: { $0.title == importantEvent.eventTitle && Calendar.current.isDate($0.startTime, inSameDayAs: importantEvent.eventDate) }),
                  event.startTime > Date() else { continue }
            
            guard let triggerDate = Calendar.current.date(byAdding: .minute, value: -importantEvent.reminderMinutes, to: event.startTime),
                  triggerDate > Date() else { continue }
            
            let timeInterval = triggerDate.timeIntervalSinceNow
            
            Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
                let notification = NSUserNotification()
                notification.title = "⚠️ Important: \(importantEvent.eventTitle)"
                notification.informativeText = "This event starts in \(importantEvent.reminderMinutes) minutes at \(event.location). Don't miss it!"
                notification.soundName = NSUserNotificationDefaultSoundName
                notification.deliveryDate = Date()
                notification.hasActionButton = false
                
                NSUserNotificationCenter.default.deliver(notification)
            }
        }
    }
}
