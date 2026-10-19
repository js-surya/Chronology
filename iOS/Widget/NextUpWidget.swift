import WidgetKit
import SwiftUI
import ChronologyCore

@main
struct ChronologyWidgets: WidgetBundle {
    var body: some Widget {
        NextUpWidget()
    }
}

// MARK: - Timeline

struct NextUpEntry: TimelineEntry {
    let date: Date
    let profileName: String
    /// Current/next event first, then the following ones.
    let events: [Event]
    let customColors: [String: CodableColor]
    let use24Hour: Bool
    let hasProfile: Bool

    static let placeholder = NextUpEntry(
        date: .now,
        profileName: "Schedule",
        events: [
            Event(title: "Linear Algebra", location: "Ravelijn 1501", startTime: .now.addingTimeInterval(1800), endTime: .now.addingTimeInterval(7200), description: nil),
            Event(title: "Databases", location: "Carre 2G", startTime: .now.addingTimeInterval(10800), endTime: .now.addingTimeInterval(14400), description: nil),
            Event(title: "Operating Systems", location: "Zilverling", startTime: .now.addingTimeInterval(18000), endTime: .now.addingTimeInterval(21600), description: nil)
        ],
        customColors: [:], use24Hour: true, hasProfile: true)
}

struct NextUpProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextUpEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }
        Task { completion(await entries(now: .now).first ?? .placeholder) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        Task {
            let now = Date.now
            let entries = await entries(now: now)
            // Ask again in an hour for fresh data, or sooner if the last entry runs out
            let refresh = min(now.addingTimeInterval(3600), entries.last?.date.addingTimeInterval(60) ?? now.addingTimeInterval(3600))
            completion(Timeline(entries: entries, policy: .after(refresh)))
        }
    }

    /// One entry now, then one at every start/end boundary so "Next Up" rolls over on time.
    private func entries(now: Date) async -> [NextUpEntry] {
        let snapshot = await loadSnapshot(now: now)
        guard let snapshot else {
            return [NextUpEntry(date: now, profileName: "", events: [], customColors: [:], use24Hour: true, hasProfile: false)]
        }
        let upcoming = snapshot.upcoming(after: now)
        var boundaries: [Date] = [now]
        for event in upcoming.prefix(6) {
            if event.startTime > now { boundaries.append(event.startTime) }
            boundaries.append(event.endTime)
        }
        return Array(Set(boundaries)).sorted().map { date in
            NextUpEntry(
                date: date,
                profileName: snapshot.profileName,
                events: snapshot.upcoming(after: date, limit: 3),
                customColors: snapshot.customColors,
                use24Hour: snapshot.use24HourFormat,
                hasProfile: true)
        }
    }

    /// The app writes a snapshot whenever it loads; refetch only when that's missing or stale.
    private func loadSnapshot(now: Date) async -> ScheduleSnapshot? {
        let defaults = AppGroup.defaults
        guard var snapshot = ScheduleSnapshot.load(from: defaults) else { return nil }
        if now.timeIntervalSince(snapshot.savedAt) > 2 * 3600, !snapshot.profileURL.isEmpty,
           let fresh = try? await ScheduleService.shared.fetchSchedule(from: snapshot.profileURL, maxAge: 0) {
            snapshot.events = ScheduleSnapshot.trimmed(fresh, now: now)
            snapshot.savedAt = now
            snapshot.save(to: defaults)
        }
        return snapshot
    }
}

// MARK: - Widget

struct NextUpWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.nextUp, provider: NextUpProvider()) { entry in
            NextUpWidgetView(entry: entry)
        }
        .configurationDisplayName("Next Up")
        .description("Your next class with a live countdown.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct NextUpWidgetView: View {
    let entry: NextUpEntry
    @Environment(\.widgetFamily) private var family

    private var next: Event? { entry.events.first }

    var body: some View {
        Group {
            if let next {
                switch family {
                case .systemMedium: medium(next)
                case .accessoryRectangular: rectangular(next)
                case .accessoryInline: inline(next)
                case .accessoryCircular: circular(next)
                default: small(next)
                }
            } else {
                empty
            }
        }
        .containerBackground(for: .widget) {
            if let next, family == .systemSmall || family == .systemMedium {
                LinearGradient(colors: [color(next).opacity(0.35), color(next).opacity(0.08)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                Color.clear
            }
        }
    }

    // MARK: Families

    private func small(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            header(event)
            Text(event.title)
                .font(.headline)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            countdown(event)
                .font(.title3.weight(.semibold))
            Text(details(event))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medium(_ event: Event) -> some View {
        HStack(alignment: .top, spacing: 14) {
            small(event)
            if entry.events.count > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("LATER")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(entry.events.dropFirst()) { later in
                        HStack(spacing: 6) {
                            Capsule().fill(color(later)).frame(width: 3, height: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(later.title).font(.caption.weight(.semibold)).lineLimit(1)
                                Text(dayAndTime(later)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func rectangular(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(event.title)
                .font(.headline)
                .widgetAccentable()
                .lineLimit(1)
            Text(details(event)).lineLimit(1)
            countdown(event)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ event: Event) -> some View {
        Text("\(event.title) · \(time(event.startTime))")
    }

    private func circular(_ event: Event) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "calendar")
                    .font(.caption2)
                Text(time(event.startTime))
                    .font(.caption.weight(.semibold))
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 6) {
            Image(systemName: entry.hasProfile ? "moon.stars" : "calendar.badge.plus")
                .font(.title2)
            Text(entry.hasProfile ? "No more classes" : "Open Chronology to add a schedule")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Pieces

    private func header(_ event: Event) -> some View {
        Text(event.startTime <= entry.date ? "NOW" : "NEXT UP")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color(event))
    }

    /// Ticks on its own between timeline entries.
    private func countdown(_ event: Event) -> some View {
        let inProgress = event.startTime <= entry.date
        let target = inProgress ? event.endTime : event.startTime
        // Minute precision ("in 29 min"); `.relative` adds seconds and truncates in small widgets
        let remaining = Text(.currentDate, format: .reference(to: target, allowedFields: [.day, .hour, .minute], maxFieldCount: 2))
        return Text(inProgress ? "ends \(remaining)" : "\(remaining)")
            .monospacedDigit()
    }

    private func details(_ event: Event) -> String {
        let range = EventStyle.timeRange(event, use24Hour: entry.use24Hour)
        return event.location.isEmpty ? range : "\(range) · \(event.location)"
    }

    private func dayAndTime(_ event: Event) -> String {
        let day = Calendar.current.isDateInToday(event.startTime) ? "" : event.startTime.formatted(.dateTime.weekday(.abbreviated)) + " "
        return day + time(event.startTime)
    }

    private func time(_ date: Date) -> String { EventStyle.time(date, use24Hour: entry.use24Hour) }

    private func color(_ event: Event) -> Color { EventStyle.color(for: event, customColors: entry.customColors) }
}

#Preview(as: .systemMedium) {
    NextUpWidget()
} timeline: {
    NextUpEntry.placeholder
}
