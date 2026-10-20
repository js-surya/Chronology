import SwiftUI
import Observation
import UserNotifications
import WidgetKit
import ChronologyCore

/// App-wide state. Persists to the App Group so the widgets see the same profile, colors and 24h setting.
@MainActor
@Observable
final class AppStore {
    // MARK: - Persisted settings

    var profiles: [ScheduleProfile] = [] {
        didSet { persist(profiles, key: Keys.profiles); pushToCloud(profiles, .profiles) }
    }
    var activeProfileID: UUID? {
        didSet {
            defaults.set(activeProfileID?.uuidString, forKey: Keys.activeProfile)
            if activeProfileID != oldValue {
                events = []
                errorMessage = nil
                Task { await refresh() }
            }
        }
    }
    var use24HourFormat = true {
        didSet { defaults.set(use24HourFormat, forKey: Keys.use24Hour); publishSnapshot(); syncLiveActivity(); pushToCloud(use24HourFormat, .timeFormat) }
    }
    /// Schedules, course colors, notes, Important classes and 24-hour time follow the user across devices.
    var iCloudSyncEnabled = true {
        didSet {
            defaults.set(iCloudSyncEnabled, forKey: Keys.iCloudSync)
            if iCloudSyncEnabled {
                // Merge again rather than trusting versions seen before sync was off
                cloud.resetSeenVersions()
                syncFromCloud()
            }
        }
    }
    var hapticsEnabled = true {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }
    /// Dynamic Island / Lock Screen activity for the current or next class.
    var liveActivityEnabled = true {
        didSet { defaults.set(liveActivityEnabled, forKey: Keys.liveActivity); syncLiveActivity() }
    }
    var notificationsEnabled = false {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications); rescheduleReminders() }
    }
    var reminderMinutes = 15 {
        didSet { defaults.set(reminderMinutes, forKey: Keys.reminderMinutes); rescheduleReminders() }
    }
    /// Alert when a class's countdown runs out: when it starts, and when it ends.
    var alertAtClassStart = true {
        didSet { defaults.set(alertAtClassStart, forKey: Keys.alertAtStart); rescheduleReminders() }
    }
    var alertAtClassEnd = false {
        didSet { defaults.set(alertAtClassEnd, forKey: Keys.alertAtEnd); rescheduleReminders() }
    }
    var appearance: Appearance = .system {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }
    /// Name of an `AccentPreset`, or "custom" for `customAccent`.
    var accentPreset = "blue" {
        didSet { defaults.set(accentPreset, forKey: Keys.accentPreset) }
    }
    var customAccent: CodableColor? {
        didSet { persist(customAccent, key: Keys.customAccent) }
    }
    /// Calendar grid range (widened automatically to fit early/late classes), like the Mac Hours setting.
    var dayStartHour = 8 {
        didSet { defaults.set(dayStartHour, forKey: Keys.dayStart) }
    }
    var dayEndHour = 20 {
        didSet { defaults.set(dayEndHour, forKey: Keys.dayEnd) }
    }
    private(set) var customColors: [String: CodableColor] = [:] {
        didSet { persist(customColors, key: Keys.customColors); publishSnapshot(); syncLiveActivity(); pushToCloud(customColors, .courseColors) }
    }
    private(set) var notes: [EventNote] = [] {
        didSet { persist(notes, key: Keys.notes); pushToCloud(notes, .notes) }
    }
    private(set) var importantEvents: [ImportantEvent] = [] {
        didSet { persist(importantEvents, key: Keys.important); rescheduleReminders(); pushToCloud(importantEvents, .importantEvents) }
    }

    // MARK: - Schedule state

    private(set) var events: [Event] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastLoaded: Date?
    /// Bumped after a pull-to-refresh, so views can play success/error haptics.
    private(set) var manualRefreshSucceeded = 0
    private(set) var manualRefreshFailed = 0

    private let defaults = AppGroup.defaults
    @ObservationIgnored private lazy var cloud = CloudSync(store: UbiquitousSyncStore(), defaults: defaults)
    /// Set while applying another device's changes, so they aren't pushed straight back.
    @ObservationIgnored private var applyingRemote = false

    private enum Keys {
        static let profiles = "profiles"
        static let activeProfile = "activeProfileID"
        static let use24Hour = "use24HourFormat"
        static let notifications = "notificationsEnabled"
        static let reminderMinutes = "reminderMinutes"
        static let customColors = "customColors"
        static let notes = "eventNotes"
        static let important = "importantEvents"
        static let appearance = "appearance"
        static let accentPreset = "accentPreset"
        static let customAccent = "customAccent"
        static let dayStart = "dayStartHour"
        static let dayEnd = "dayEndHour"
        static let liveActivity = "liveActivityEnabled"
        static let alertAtStart = "alertAtClassStart"
        static let alertAtEnd = "alertAtClassEnd"
        static let haptics = "hapticsEnabled"
        static let iCloudSync = "iCloudSyncEnabled"
    }

    init() {
        // Property observers don't run during init, so loading doesn't re-save or refetch
        profiles = load([ScheduleProfile].self, key: Keys.profiles) ?? []
        activeProfileID = defaults.string(forKey: Keys.activeProfile).flatMap(UUID.init(uuidString:)) ?? profiles.first?.id
        use24HourFormat = defaults.object(forKey: Keys.use24Hour) as? Bool ?? true
        notificationsEnabled = defaults.bool(forKey: Keys.notifications)
        reminderMinutes = defaults.object(forKey: Keys.reminderMinutes) as? Int ?? 15
        customColors = load([String: CodableColor].self, key: Keys.customColors) ?? [:]
        notes = load([EventNote].self, key: Keys.notes) ?? []
        importantEvents = load([ImportantEvent].self, key: Keys.important) ?? []
        appearance = defaults.string(forKey: Keys.appearance).flatMap(Appearance.init(rawValue:)) ?? .system
        accentPreset = defaults.string(forKey: Keys.accentPreset) ?? "blue"
        customAccent = load(CodableColor.self, key: Keys.customAccent)
        dayStartHour = defaults.object(forKey: Keys.dayStart) as? Int ?? 8
        dayEndHour = defaults.object(forKey: Keys.dayEnd) as? Int ?? 20
        liveActivityEnabled = defaults.object(forKey: Keys.liveActivity) as? Bool ?? true
        alertAtClassStart = defaults.object(forKey: Keys.alertAtStart) as? Bool ?? true
        alertAtClassEnd = defaults.object(forKey: Keys.alertAtEnd) as? Bool ?? false
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        iCloudSyncEnabled = defaults.object(forKey: Keys.iCloudSync) as? Bool ?? true
        // Show the last snapshot immediately; a refresh replaces it
        if let snapshot = ScheduleSnapshot.load(from: defaults), snapshot.profileURL == activeProfile?.icalUrl {
            events = snapshot.events
        }
    }

    // MARK: - Profiles

    var activeProfile: ScheduleProfile? {
        profiles.first { $0.id == activeProfileID } ?? profiles.first
    }

    func addProfile(_ profile: ScheduleProfile) {
        profiles.append(profile)
        activeProfileID = profile.id
    }

    func updateProfile(_ profile: ScheduleProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        let urlChanged = profiles[index].icalUrl != profile.icalUrl
        profiles[index] = profile
        if urlChanged && profile.id == activeProfileID {
            Task { await refresh(force: true) }
        }
    }

    func deleteProfiles(at offsets: IndexSet) {
        let removedActive = offsets.contains { profiles[$0].id == activeProfileID }
        profiles.remove(atOffsets: offsets)
        if removedActive { activeProfileID = profiles.first?.id }
    }

    // MARK: - Loading

    /// `force` bypasses ScheduleService's 15-minute cache (pull to refresh).
    func refresh(force: Bool = false) async {
        guard let profile = activeProfile, !profile.icalUrl.isEmpty else {
            events = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await ScheduleService.shared.fetchSchedule(
                from: profile.icalUrl,
                maxAge: force ? 0 : ScheduleService.defaultMaxAge
            )
            // The profile may have changed while the request was in flight
            guard profile.id == activeProfile?.id else { return }
            events = fetched
            errorMessage = nil
            lastLoaded = Date()
            publishSnapshot()
            rescheduleReminders()
            syncLiveActivity()
            if force { manualRefreshSucceeded += 1 }
        } catch {
            guard profile.id == activeProfile?.id else { return }
            errorMessage = error.localizedDescription
            if force { manualRefreshFailed += 1 }
        }
    }

    /// Refresh when returning to the app if the data is older than the cache window.
    func refreshIfStale() async {
        if let lastLoaded, Date().timeIntervalSince(lastLoaded) < ScheduleService.defaultMaxAge {
            syncLiveActivity()
            return
        }
        await refresh()
    }

    // MARK: - iCloud sync

    var iCloudAvailable: Bool { UbiquitousSyncStore.isAvailable }

    /// Pulls other devices' changes now and whenever they save.
    func startCloudSync() {
        cloud.start { [weak self] in self?.syncFromCloud() }
        syncFromCloud()
    }

    func syncFromCloud() {
        guard iCloudSyncEnabled else { return }
        applyingRemote = true
        defer { applyingRemote = false }
        if let value = cloud.reconcile(.profiles, local: profiles, firstMerge: CloudSync.union) { profiles = value }
        if let value = cloud.reconcile(.courseColors, local: customColors, firstMerge: CloudSync.union) { customColors = value }
        if let value = cloud.reconcile(.notes, local: notes, firstMerge: CloudSync.union) { notes = value }
        if let value = cloud.reconcile(.importantEvents, local: importantEvents, firstMerge: CloudSync.union) { importantEvents = value }
        if let value = cloud.reconcile(.timeFormat, local: use24HourFormat, firstMerge: { remote, _ in remote }) { use24HourFormat = value }
        // A schedule deleted on another device may have been the active one
        if let active = activeProfileID, !profiles.contains(where: { $0.id == active }) {
            activeProfileID = profiles.first?.id
        } else if activeProfileID == nil, let first = profiles.first {
            activeProfileID = first.id
        }
    }

    private func pushToCloud<T: Codable>(_ value: T, _ section: SyncSection) {
        guard iCloudSyncEnabled, !applyingRemote else { return }
        cloud.push(value, to: section)
    }

    // MARK: - Live Activity

    private var boundaryTask: Task<Void, Never>?

    var liveActivitiesAllowedBySystem: Bool { LiveActivityController.systemAllowsActivities }

    /// Brings the Live Activity in line with the schedule, then re-syncs at the next class
    /// boundary while the app keeps running (the stale date covers the rest).
    func syncLiveActivity() {
        let events = events, enabled = liveActivityEnabled, use24 = use24HourFormat
        let name = activeProfile?.name ?? AboutText.appName
        let colors = customColors
        Task {
            await LiveActivityController.sync(
                enabled: enabled, events: events, profileName: name,
                color: { colors[$0.title] ?? CodableColor(color: $0.color(from: $0.title)) },
                use24Hour: use24)
        }

        boundaryTask?.cancel()
        let now = Date()
        let next = events.flatMap { [$0.startTime.addingTimeInterval(-LiveActivityController.leadTime), $0.startTime, $0.endTime] }
            .filter { $0 > now }
            .min()
        guard enabled, let next else { return }
        boundaryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(next.timeIntervalSince(now) + 1))
            guard !Task.isCancelled else { return }
            self?.syncLiveActivity()
        }
    }

    // MARK: - Appearance

    var accentColor: Color {
        if accentPreset == "custom", let customAccent { return customAccent.color }
        return AccentPreset.all.first { $0.id == accentPreset }?.color ?? .blue
    }

    // MARK: - Presentation

    func color(for event: Event) -> Color {
        EventStyle.color(for: event, customColors: customColors)
    }

    func time(_ date: Date) -> String {
        EventStyle.time(date, use24Hour: use24HourFormat)
    }

    func timeRange(_ event: Event) -> String {
        EventStyle.timeRange(event, use24Hour: use24HourFormat)
    }

    func upcoming(now: Date = Date()) -> [Event] {
        events.filter { !$0.isAllDay && $0.endTime > now }.sorted { $0.startTime < $1.startTime }
    }

    // MARK: - Customizations

    func setColor(_ color: Color?, for event: Event) {
        if let color {
            customColors[event.title] = CodableColor(color: color)
        } else {
            customColors[event.title] = nil
        }
    }

    func hasCustomColor(_ event: Event) -> Bool { customColors[event.title] != nil }

    func note(for event: Event) -> String {
        notes.first { $0.eventTitle == event.title && Calendar.current.isDate($0.eventDate, inSameDayAs: event.startTime) }?.note ?? ""
    }

    func setNote(_ text: String, for event: Event) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = notes.firstIndex(where: { $0.eventTitle == event.title && Calendar.current.isDate($0.eventDate, inSameDayAs: event.startTime) }) {
            if trimmed.isEmpty {
                notes.remove(at: index)
            } else {
                notes[index].note = trimmed
                notes[index].modifiedAt = Date()
            }
        } else if !trimmed.isEmpty {
            notes.append(EventNote(eventTitle: event.title, eventDate: event.startTime, note: trimmed))
        }
    }

    func isImportant(_ event: Event) -> Bool {
        importantEvents.contains { $0.matches(event) }
    }

    /// Marking important also turns reminders on, since that's what it's for.
    func toggleImportant(_ event: Event) async {
        if isImportant(event) {
            importantEvents.removeAll { $0.matches(event) }
        } else {
            importantEvents.append(ImportantEvent(eventTitle: event.title, eventDate: event.startTime, reminderMinutes: reminderMinutes))
            if !notificationsEnabled {
                await setNotificationsEnabled(true)
            }
        }
    }

    /// Starred events still ahead, soonest first (the Mac "Important" list).
    func importantUpcoming(now: Date = Date()) -> [Event] {
        upcoming(now: now).filter(isImportant)
    }

    func reminderMinutes(for event: Event) -> Int {
        importantEvents.first { $0.matches(event) }?.reminderMinutes ?? reminderMinutes
    }

    func setReminderMinutes(_ minutes: Int, for event: Event) {
        guard let index = importantEvents.firstIndex(where: { $0.matches(event) }) else { return }
        importantEvents[index].reminderMinutes = minutes
    }

    // MARK: - Reminders

    /// Delivers a notification in a few seconds so the user can confirm alerts work.
    func sendTestNotification() async -> String {
        let center = UNUserNotificationCenter.current()
        var status = await center.notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
            status = await center.notificationSettings().authorizationStatus
        }
        guard status == .authorized || status == .provisional else {
            return "Notifications are off. Allow them for Chronology in the Settings app."
        }
        let content = UNMutableNotificationContent()
        content.title = "Chronology Test"
        content.body = "Reminders are working."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        do {
            try await center.add(UNNotificationRequest(identifier: "chronology.test", content: content, trigger: trigger))
            return "Test sent — it arrives in 3 seconds."
        } catch {
            return error.localizedDescription
        }
    }

    /// Asks for permission when turning on; stays off if the user declines.
    func setNotificationsEnabled(_ enabled: Bool) async {
        guard enabled else {
            notificationsEnabled = false
            return
        }
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        notificationsEnabled = granted
    }

    private func rescheduleReminders() {
        guard notificationsEnabled else {
            ReminderScheduler.cancelAll()
            return
        }
        ReminderScheduler.replacePending(with: NotificationPlanner.plan(
            events: events, minutesBefore: reminderMinutes, importantEvents: importantEvents, now: Date(),
            atStart: alertAtClassStart, atEnd: alertAtClassEnd))
    }

    // MARK: - Widgets

    private func publishSnapshot() {
        guard let profile = activeProfile else { return }
        ScheduleSnapshot(
            profileName: profile.name,
            profileURL: profile.icalUrl,
            events: ScheduleSnapshot.trimmed(events),
            customColors: customColors,
            use24HourFormat: use24HourFormat
        ).save(to: defaults)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Persistence

    private func persist<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}

// MARK: - Appearance options

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Same accent presets as the Mac app.
struct AccentPreset: Identifiable {
    let id: String
    let color: Color

    static let all: [AccentPreset] = [
        .init(id: "blue", color: .blue),
        .init(id: "purple", color: .purple),
        .init(id: "pink", color: .pink),
        .init(id: "red", color: .red),
        .init(id: "orange", color: .orange),
        .init(id: "green", color: .green),
        .init(id: "teal", color: .teal)
    ]
}
