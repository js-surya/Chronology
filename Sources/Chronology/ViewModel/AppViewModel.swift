import Foundation
import SwiftUI
import Combine
import UserNotifications
import ChronologyCore

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Settings Storage
    @AppStorage("use24HourFormat") var use24HourFormat: Bool = true {
        didSet { pushToCloud(use24HourFormat, .timeFormat) }
    }
    /// Schedules, course colors, notes, Important classes and 24-hour time follow the user across devices.
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled: Bool = true {
        didSet {
            if iCloudSyncEnabled {
                // Merge again rather than trusting versions seen before sync was off
                cloud.resetSeenVersions()
                syncFromCloud()
            }
        }
    }
    @AppStorage("startHour") var startHour: Int = 8
    @AppStorage("endHour") var endHour: Int = 20
    
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = false {
        didSet {
            if notificationsEnabled {
                NotificationManager.shared.requestAuthorization()
                NotificationCenter.default.post(name: .rescheduleNotifications, object: nil)
            } else {
                NotificationManager.shared.cancelAll()
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
    @AppStorage("preferredDarkMode") var preferredDarkMode: String = "dark" // "dark", "darkSolid" or "amoled" - used when in auto mode
    
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
    @AppStorage("activeProfileId") var activeProfileId: String = "" {
        didSet {
            // Refresh the countdown immediately instead of waiting for the next timer tick
            if hasInitialized { updateMenuBarText() }
        }
    }
    
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
    /// Settings sheet on the main window; set from the menu bar too, so it survives the window being recreated
    @Published var showingSettings = false
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
        
        if iCloudInBuild {
            cloud.start { [weak self] in self?.syncFromCloud() }
            syncFromCloud()
        }
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
            // Served from ScheduleService's cache; the network is hit at most every defaultMaxAge
            let events = (try? await ScheduleService.shared.fetchSchedule(from: url)) ?? []
            menuBarText = Countdown.menuBarLabel(for: events, now: Date())
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
                ? (preferredDarkMode == "amoled" ? .amoled : preferredDarkMode == "darkSolid" ? .darkSolid : .dark)
                : .light
        default:          return .light
        }
    }

    func toggleImportant(_ event: Event) {
        if isEventImportant(event) {
            importantEvents.removeAll { $0.eventTitle == event.title && abs($0.eventDate.timeIntervalSince(event.startTime)) < 60 }
            saveImportantEvents()
            NotificationCenter.default.post(name: .rescheduleNotifications, object: nil)
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
    
    // MARK: - iCloud sync
    
    private lazy var cloud = CloudSync(store: UbiquitousSyncStore(), defaults: .standard)
    /// Set while applying another device's changes, so they aren't pushed straight back.
    private var applyingRemote = false
    
    var iCloudAvailable: Bool { UbiquitousSyncStore.isAvailable }
    var iCloudInBuild: Bool { UbiquitousSyncStore.isEnabledInBuild }
    
    /// The Mac keeps course colors as a list; the synced form is title → color, like iOS.
    private var courseColors: [String: CodableColor] {
        Dictionary(courseCustomizations.compactMap { c in c.customColor.map { (c.courseName, $0) } },
                   uniquingKeysWith: { first, _ in first })
    }
    
    func syncFromCloud() {
        guard iCloudSyncEnabled, iCloudInBuild, hasInitialized else { return }
        applyingRemote = true
        defer { applyingRemote = false }
        if let value = cloud.reconcile(.profiles, local: profiles, firstMerge: CloudSync.union) {
            profiles = value
            saveProfiles()
            if !profiles.contains(where: { $0.id.uuidString == activeProfileId }) {
                activeProfileId = profiles.first?.id.uuidString ?? ""
            }
        }
        if let value = cloud.reconcile(.courseColors, local: courseColors, firstMerge: CloudSync.union) {
            courseCustomizations = value.map { CourseCustomization(courseName: $0.key, customColor: $0.value) }
            saveCustomizations()
        }
        if let value = cloud.reconcile(.notes, local: eventNotes, firstMerge: CloudSync.union) {
            eventNotes = value
            saveEventNotes()
        }
        if let value = cloud.reconcile(.importantEvents, local: importantEvents, firstMerge: CloudSync.union) {
            importantEvents = value
            saveImportantEvents()
            NotificationCenter.default.post(name: .rescheduleNotifications, object: nil)
        }
        if let value = cloud.reconcile(.timeFormat, local: use24HourFormat, firstMerge: { remote, _ in remote }) {
            use24HourFormat = value
        }
    }
    
    private func pushToCloud<T: Codable>(_ value: T, _ section: SyncSection) {
        guard iCloudSyncEnabled, iCloudInBuild, hasInitialized, !applyingRemote else { return }
        cloud.push(value, to: section)
    }
    
    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            profilesData = encoded
        }
        pushToCloud(profiles, .profiles)
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
        pushToCloud(courseColors, .courseColors)
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
        pushToCloud(eventNotes, .notes)
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
        pushToCloud(importantEvents, .importantEvents)
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
