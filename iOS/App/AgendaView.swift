import SwiftUI
import ChronologyCore

/// Next Up card plus the coming two weeks, grouped by day.
struct AgendaView: View {
    @Binding var selectedEvent: Event?
    @Environment(AppStore.self) private var store

    var body: some View {
        NavigationStack {
            // Re-evaluated every minute so Next Up and past events roll over on their own
            TimelineView(.everyMinute) { context in
                content(now: context.date)
            }
            .navigationTitle(store.activeProfile?.name ?? "Up Next")
            .toolbar { ProfileSwitcher() }
            .refreshable { await store.refresh(force: true) }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let upcoming = store.upcoming(now: now)
        if upcoming.isEmpty {
            ScheduleStatusView()
        } else {
            List {
                if let next = upcoming.first {
                    // In the header so the glass card floats free of the grouped-row background
                    Section {
                    } header: {
                        Button { selectedEvent = next } label: {
                            NextUpCard(event: next, now: now)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary) // headers default to secondary text
                        .textCase(nil)
                        .padding(.bottom, 8)
                    }
                }
                ForEach(days(from: upcoming, now: now), id: \.day) { group in
                    Section(header: Text(dayTitle(group.day, now: now))) {
                        ForEach(group.events) { event in
                            Button { selectedEvent = event } label: {
                                EventRow(event: event, now: now)
                            }
                            .tint(.primary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private struct DayGroup {
        let day: Date
        let events: [Event]
    }

    private func days(from events: [Event], now: Date) -> [DayGroup] {
        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now
        let grouped = Dictionary(grouping: events.filter { $0.startTime < horizon }) {
            Calendar.current.startOfDay(for: $0.startTime)
        }
        return grouped.keys.sorted().map { DayGroup(day: $0, events: grouped[$0] ?? []) }
    }

    private func dayTitle(_ day: Date, now: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return "Today" }
        if cal.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

// MARK: - Next Up card

struct NextUpCard: View {
    let event: Event
    let now: Date
    @Environment(AppStore.self) private var store

    private var inProgress: Bool { event.startTime <= now }

    var body: some View {
        let color = store.color(for: event)
        VStack(alignment: .leading, spacing: 8) {
            Text(inProgress ? "NOW" : "NEXT UP")
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(color)

            Text(event.title)
                .font(.title2.weight(.semibold))
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 4) {
                Label(store.timeRange(event), systemImage: "clock")
                    .monospacedDigit()
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(Countdown.phrase(for: event, now: now))
                .font(.system(.title, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(color.opacity(0.25)).interactive(), in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows event details")
    }
}

// MARK: - Row

struct EventRow: View {
    let event: Event
    var now: Date = Date()
    var showsDate = false
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            Capsule()
                .fill(store.color(for: event))
                .frame(width: 4)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if store.isImportant(event) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityLabel("Important")
            }
            if event.startTime <= now && event.endTime > now {
                Text("Now")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(store.color(for: event).opacity(0.2), in: .capsule)
            }
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
    }

    private var subtitle: String {
        var parts: [String] = []
        if showsDate { parts.append(event.startTime.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) }
        parts.append(store.timeRange(event))
        if !event.location.isEmpty { parts.append(event.location) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Loading / empty / error

struct ScheduleStatusView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        if store.isLoading && store.events.isEmpty {
            ProgressView("Loading Schedule…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = store.errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load Schedule", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { Task { await store.refresh(force: true) } }
                    .buttonStyle(.glassProminent)
            }
        } else if store.events.isEmpty {
            ContentUnavailableView {
                Label("No Events", systemImage: "calendar")
            } description: {
                Text("This calendar is empty. If the term ended, copy a new iCal link from TimeEdit.")
            } actions: {
                Button("Refresh") { Task { await store.refresh(force: true) } }
                    .buttonStyle(.glass)
            }
        } else {
            ContentUnavailableView("All Done", systemImage: "moon.stars",
                                   description: Text("Nothing else coming up."))
        }
    }
}
