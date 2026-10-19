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
        didSet { persist(profiles, key: Keys.profiles) }
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
        didSet { defaults.set(use24HourFormat, forKey: Keys.use24Hour); publishSnapshot() }
    }
    var notificationsEnabled = false {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications); rescheduleReminders() }
    }
    var reminderMinutes = 15 {
        didSet { defaults.set(reminderMinutes, forKey: Keys.reminderMinutes); rescheduleReminders() }
    }
    private(set) var customColors: [String: CodableColor] = [:] {
        didSet { persist(customColors, key: Keys.customColors); publishSnapshot() }
    }
    private(set) var notes: [EventNote] = [] {
        didSet { persist(notes, key: Keys.notes) }
    }
    private(set) var importantEvents: [ImportantEvent] = [] {
        didSet { persist(importantEvents, key: Keys.important); rescheduleReminders() }
    }

    // MARK: - Schedule state

    private(set) var events: [Event] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var lastLoaded: Date?

    private let defaults = AppGroup.defaults

    private enum Keys {
        static let profiles = "profiles"
        static let activeProfile = "activeProfileID"
        static let use24Hour = "use24HourFormat"
        static let notifications = "notificationsEnabled"
        static let reminderMinutes = "reminderMinutes"
        static let customColors = "customColors"
        static let notes = "eventNotes"
        static let important = "importantEvents"
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
        } catch {
            guard profile.id == activeProfile?.id else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Refresh when returning to the app if the data is older than the cache window.
    func refreshIfStale() async {
        if let lastLoaded, Date().timeIntervalSince(lastLoaded) < ScheduleService.defaultMaxAge { return }
        await refresh()
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

    // MARK: - Reminders

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
            events: events, minutesBefore: reminderMinutes, importantEvents: importantEvents, now: Date()))
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
