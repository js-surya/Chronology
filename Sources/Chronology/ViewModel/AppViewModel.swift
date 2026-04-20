import Foundation
import SwiftUI
import Combine
import UserNotifications

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Settings Storage
    @AppStorage("use24HourFormat") var use24HourFormat: Bool = true
    @AppStorage("startHour") var startHour: Int = 8
    @AppStorage("endHour") var endHour: Int = 20
    
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = false {
        didSet {
            if notificationsEnabled {
                NotificationManager.shared.requestAuthorization()
                NotificationCenter.default.post(name: .rescheduleNotifications, object: nil)
            } else {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
        }
    }
    @AppStorage("notificationMinutesBefore") var notificationMinutesBefore: Int = 15 {
        didSet {
            if notificationsEnabled {
                NotificationCenter.default.post(name: .rescheduleNotifications, object: nil)
            }
        }
    }
    
    @AppStorage("themeMode") var themeMode: String = "auto" // "light", "dark", "amoled", "auto"
    @AppStorage("preferredDarkMode") var preferredDarkMode: String = "dark" // "dark" or "amoled" - used when in auto mode
    
    @Published var accentColor: Color = .blue
    @AppStorage("accentColorData") private var accentColorData: Data = Data()
    
    // MARK: - Event Card Customization
    @AppStorage("eventCardStyle") var eventCardStyle: String = "filled" // "filled", "bordered", "minimal"
    @AppStorage("eventCornerRadius") var eventCornerRadius: Double = 6
    @AppStorage("eventShadowEnabled") var eventShadowEnabled: Bool = true
    @AppStorage("eventBorderWidth") var eventBorderWidth: Double = 1.5
    @AppStorage("showEventIcons") var showEventIcons: Bool = true
    
    // MARK: - Grid Background Customization
    @AppStorage("gridBackgroundOpacity") var gridBackgroundOpacity: Double = 0.05
    @AppStorage("gridLineThickness") var gridLineThickness: Double = 0.5
    @AppStorage("gridLineOpacity") var gridLineOpacity: Double = 0.2
    
    // MARK: - Profile Management
    @Published var profiles: [ScheduleProfile] = []
    @AppStorage("profilesData") private var profilesData: Data = Data()
    @AppStorage("activeProfileId") var activeProfileId: String = ""
    
    // MARK: - Customizations
    @Published var courseCustomizations: [CourseCustomization] = []
    @AppStorage("courseCustomizationsData") private var courseCustomizationsData: Data = Data()
    
    @Published var eventNotes: [EventNote] = []
    @AppStorage("eventNotesData") private var eventNotesData: Data = Data()
    
    @Published var importantEvents: [ImportantEvent] = []
    @AppStorage("importantEventsData") private var importantEventsData: Data = Data()
    
    // MARK: - View Mode
    @AppStorage("viewMode") var viewMode: String = "week" // "week" or "day"
    
    // MARK: - Menu Bar Logic
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("hideFromDock") var hideFromDock: Bool = false {
        didSet {
            updateDockIconVisibility()
        }
    }
    @Published var menuBarText: String = "✓"
    private var menuBarTimer: Timer?
    
    // MARK: - Initialization
    private var hasInitialized = false
    
    init() {
        // Empty init - defer all loading
    }
    
    func ensureInitialized() {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        loadProfiles()
        loadCustomizations()
        loadEventNotes()
        loadImportantEvents()
        loadAccentColor()
        
        // Migrate legacy URL if needed (one-time check)
        if profiles.isEmpty {
            let legacyUrl = UserDefaults.standard.string(forKey: "timeEditUrl") ?? ""
            if !legacyUrl.isEmpty {
                let defaultProfile = ScheduleProfile(name: "My Schedule", icalUrl: legacyUrl)
                addProfile(defaultProfile)
                UserDefaults.standard.removeObject(forKey: "timeEditUrl")
            }
        }
        
        // Auto-select first profile for menu bar if no active profile
        if activeProfileId.isEmpty && !profiles.isEmpty {
            activeProfileId = profiles[0].id.uuidString
        }
        
        // Request notification authorization if enabled (handles case where permission was reset or not yet granted)
        if notificationsEnabled {
            NotificationManager.shared.requestAuthorization()
        }
        
        startMenuBarUpdates()
    }
    
    func startMenuBarUpdates() {
        updateMenuBarText()
        updateDockIconVisibility()
        // Update every minute for countdown timer
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMenuBarText()
            }
        }
    }
    
    func updateDockIconVisibility() {
        if hideFromDock {
            NSApp.setActivationPolicy(.accessory) // Hide dock icon but keep menu bar
        } else {
            NSApp.setActivationPolicy(.regular) // Show dock icon
        }
    }
    
    func updateMenuBarText() {
        guard let url = activeProfile?.icalUrl, !url.isEmpty else {
            menuBarText = "✓"
            return
        }
        
        Task {
            do {
                // Note: Ideally we should cache this data instead of fetching every time
                // For now, we'll fetch to get the latest
                let events = try await ScheduleService.shared.fetchSchedule(from: url)
                let now = Date()
                
                // Find next event
                let upcomingEvents = events.filter { $0.endTime > now }.sorted { $0.startTime < $1.startTime }
                
                if let nextEvent = upcomingEvents.first {
                    let timeUntil = nextEvent.startTime.timeIntervalSince(now)
                    
                    if timeUntil <= 0 {
                        // Event is happening now - show remaining time
                        let timeRemaining = nextEvent.endTime.timeIntervalSince(now)
                        menuBarText = formatCountdown(timeRemaining, prefix: "")
                    } else {
                        // Event is in future - show countdown
                        menuBarText = formatCountdown(timeUntil, prefix: "")
                    }
                } else {
                    menuBarText = "✓"
                }
            } catch {
                print("Failed to update menu bar: \(error)")
                menuBarText = "✓"
            }
        }
    }
    
    private func formatCountdown(_ timeInterval: TimeInterval, prefix: String) -> String {
        let totalMinutes = Int(timeInterval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            return String(format: "0:%02d", minutes)
        }
    }
    
    func loadAccentColor() {
        if let decoded = try? JSONDecoder().decode(CodableColor.self, from: accentColorData) {
            accentColor = decoded.color
        }
    }
    
    func saveAccentColor(_ color: Color) {
        accentColor = color
        if let encoded = try? JSONEncoder().encode(CodableColor(color: color)) {
            accentColorData = encoded
        } else {
        }
        objectWillChange.send() // Force UI update
    }
    
    // MARK: - Profile Logic
    
    var activeProfile: ScheduleProfile? {
        profiles.first(where: { $0.id.uuidString == activeProfileId })
    }
    
    var activeProfileUrl: String {
        activeProfile?.icalUrl ?? ""
    }
    
    func resolvedTheme(for systemScheme: ColorScheme) -> AppTheme {
        switch themeMode {
        case "light":     return .light
        case "dark":      return .dark
        case "darkSolid": return .darkSolid
        case "amoled":    return .amoled
        case "auto":
            return systemScheme == .dark
                ? (preferredDarkMode == "amoled" ? .amoled : .dark)
                : .light
        default:          return .light
        }
    }

    func toggleImportant(_ event: Event) {
        if isEventImportant(event) {
            importantEvents.removeAll { $0.eventTitle == event.title && abs($0.eventDate.timeIntervalSince(event.startTime)) < 60 }
            saveImportantEvents()
        } else {
            let ie = ImportantEvent(eventTitle: event.title, eventDate: event.startTime, reminderMinutes: 15)
            importantEvents.append(ie)
            saveImportantEvents()
            NotificationCenter.default.post(name: .rescheduleNotifications, object: nil)
        }
    }

    func loadProfiles() {
        if let decoded = try? JSONDecoder().decode([ScheduleProfile].self, from: profilesData) {
            profiles = decoded
        }
    }
    
    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            profilesData = encoded
        }
    }
    
    func addProfile(_ profile: ScheduleProfile) {
        profiles.append(profile)
        saveProfiles()
        if profiles.count == 1 {
            activeProfileId = profile.id.uuidString
        }
    }
    
    func updateProfile(_ profile: ScheduleProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            saveProfiles()
            objectWillChange.send() // Trigger UI update
        }
    }
    
    func deleteProfile(_ profile: ScheduleProfile) {
        profiles.removeAll { $0.id == profile.id }
        saveProfiles()
        
        if activeProfileId == profile.id.uuidString {
            activeProfileId = profiles.first?.id.uuidString ?? ""
        }
    }
    
    func moveProfile(from source: IndexSet, to destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
        saveProfiles()
    }
    
    func switchToProfile(_ profile: ScheduleProfile) {
        activeProfileId = profile.id.uuidString
    }
    
    // MARK: - Course Customizations
    
    func loadCustomizations() {
        if let decoded = try? JSONDecoder().decode([CourseCustomization].self, from: courseCustomizationsData) {
            courseCustomizations = decoded
        }
    }
    
    func saveCustomizations() {
        if let encoded = try? JSONEncoder().encode(courseCustomizations) {
            courseCustomizationsData = encoded
        }
    }
    
    func getCustomColor(for courseName: String) -> Color? {
        courseCustomizations.first(where: { $0.courseName == courseName })?.customColor?.color
    }
    
    func setCustomColor(for courseName: String, color: Color?) {
        if let index = courseCustomizations.firstIndex(where: { $0.courseName == courseName }) {
            if let color = color {
                courseCustomizations[index].customColor = CodableColor(color: color)
            } else {
                courseCustomizations.remove(at: index)
            }
        } else if let color = color {
            let customization = CourseCustomization(courseName: courseName, customColor: CodableColor(color: color))
            courseCustomizations.append(customization)
        }
        saveCustomizations()
    }
    
    // MARK: - Event Notes
    
    func loadEventNotes() {
        if let decoded = try? JSONDecoder().decode([EventNote].self, from: eventNotesData) {
            eventNotes = decoded
        }
    }
    
    func saveEventNotes() {
        if let encoded = try? JSONEncoder().encode(eventNotes) {
            eventNotesData = encoded
        }
    }
    
    func getNote(for event: Event) -> EventNote? {
        let calendar = Calendar.current
        return eventNotes.first { note in
            note.eventTitle == event.title &&
            calendar.isDate(note.eventDate, inSameDayAs: event.startTime)
        }
    }
    
    func saveNote(for event: Event, noteText: String) {
        let calendar = Calendar.current
        
        if let index = eventNotes.firstIndex(where: {
            $0.eventTitle == event.title &&
            calendar.isDate($0.eventDate, inSameDayAs: event.startTime)
        }) {
            if noteText.isEmpty {
                eventNotes.remove(at: index)
            } else {
                eventNotes[index].note = noteText
                eventNotes[index].modifiedAt = Date()
            }
        } else if !noteText.isEmpty {
            let note = EventNote(eventTitle: event.title, eventDate: event.startTime, note: noteText)
            eventNotes.append(note)
        }
        saveEventNotes()
    }
    
    // MARK: - Important Events
    
    func loadImportantEvents() {
        if let decoded = try? JSONDecoder().decode([ImportantEvent].self, from: importantEventsData) {
            importantEvents = decoded
        }
    }
    
    func saveImportantEvents() {
        if let encoded = try? JSONEncoder().encode(importantEvents) {
            importantEventsData = encoded
        }
    }
    
    func isEventImportant(_ event: Event) -> Bool {
        importantEvents.contains { $0.eventTitle == event.title && abs($0.eventDate.timeIntervalSince(event.startTime)) < 60 }
    }
    
    func getImportantEvent(_ event: Event) -> ImportantEvent? {
        importantEvents.first { $0.eventTitle == event.title && abs($0.eventDate.timeIntervalSince(event.startTime)) < 60 }
    }
}

extension Notification.Name {
    static let rescheduleNotifications = Notification.Name("rescheduleNotifications")
}
