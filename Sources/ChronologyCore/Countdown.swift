import Foundation

public enum Countdown {
    /// The class a Live Activity should show: the one in progress, else the next one starting within `leadTime`.
    public static func liveActivityTarget(in events: [Event], now: Date, leadTime: TimeInterval) -> Event? {
        let upcoming = events.filter { !$0.isAllDay && $0.endTime > now }.sorted { $0.startTime < $1.startTime }
        if let current = upcoming.first(where: { $0.startTime <= now }) { return current }
        return upcoming.first { $0.startTime.timeIntervalSince(now) <= leadTime }
    }

    /// Countdown to the next timed event, or time remaining in the current one. "✓" when nothing is left.
    public static func menuBarLabel(for events: [Event], now: Date) -> String {
        let next = events
            .filter { !$0.isAllDay && $0.endTime > now }
            .min { $0.startTime < $1.startTime }
        guard let next else { return "✓" }

        let timeUntil = next.startTime.timeIntervalSince(now)
        return format(timeUntil > 0 ? timeUntil : next.endTime.timeIntervalSince(now))
    }

    /// "0:05", "2:30", or "3d" once the gap reaches a day.
    public static func format(_ timeInterval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(timeInterval / 60))
        let days = totalMinutes / (24 * 60)
        if days > 0 { return "\(days)d" }
        return String(format: "%d:%02d", totalMinutes / 60, totalMinutes % 60)
    }

    /// "In 45m" / "In 2h 5m" before the event, "Ends in 20m" while it runs.
    public static func phrase(for event: Event, now: Date) -> String {
        let inProgress = event.startTime <= now
        let target = inProgress ? event.endTime : event.startTime
        let minutes = max(0, Int(target.timeIntervalSince(now) / 60))
        let span: String
        if minutes >= 24 * 60 {
            span = "\(minutes / (24 * 60))d \((minutes % (24 * 60)) / 60)h"
        } else if minutes >= 60 {
            span = minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
        } else {
            span = "\(minutes)m"
        }
        return inProgress ? "Ends in \(span)" : "In \(span)"
    }
}
