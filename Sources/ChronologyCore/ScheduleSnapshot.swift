import Foundation

/// Upcoming events written by an app for its widgets (shared through an App Group).
public struct ScheduleSnapshot: Codable, Sendable {
    public var profileName: String
    public var profileURL: String
    public var events: [Event]
    public var customColors: [String: CodableColor]
    public var use24HourFormat: Bool
    public var savedAt: Date

    public init(profileName: String, profileURL: String, events: [Event], customColors: [String: CodableColor] = [:], use24HourFormat: Bool = true, savedAt: Date = Date()) {
        self.profileName = profileName
        self.profileURL = profileURL
        self.events = events
        self.customColors = customColors
        self.use24HourFormat = use24HourFormat
        self.savedAt = savedAt
    }

    /// Timed events that haven't ended yet, soonest first.
    public func upcoming(after now: Date, limit: Int = .max) -> [Event] {
        Array(events.filter { !$0.isAllDay && $0.endTime > now }.sorted { $0.startTime < $1.startTime }.prefix(limit))
    }

    // MARK: - Persistence

    private static let key = "scheduleSnapshot"

    public static func load(from defaults: UserDefaults?) -> ScheduleSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ScheduleSnapshot.self, from: data)
    }

    public func save(to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }

    /// Keeps the snapshot small: events from the start of today through `days` ahead.
    public static func trimmed(_ events: [Event], days: Int = 14, now: Date = Date()) -> [Event] {
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? now
        return events.filter { $0.endTime >= start && $0.startTime < end }.sorted { $0.startTime < $1.startTime }
    }
}
