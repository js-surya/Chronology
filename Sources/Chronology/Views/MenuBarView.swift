import SwiftUI
import ChronologyCore

struct MenuBarView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var events: [Event] = []
    @State private var tomorrowEvents: [Event] = []
    @State private var isLoading = false
    @State private var listHeight: CGFloat = 0

    // The header already shows the next event, so the lists start after it
    private var laterToday: [Event] { Array(events.dropFirst()) }
    private var tomorrowList: [Event] { events.isEmpty ? Array(tomorrowEvents.dropFirst()) : tomorrowEvents }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().opacity(0.25)

            if isLoading {
                ProgressView()
                    .padding(24)
                    .frame(maxWidth: .infinity)
            } else if events.isEmpty && tomorrowEvents.isEmpty {
                emptyState
            } else if !laterToday.isEmpty || !tomorrowList.isEmpty {
                eventsList
                Divider().opacity(0.25)
            }

            footerSection
        }
        .frame(width: 320)
        .onAppear { loadTodayEvents() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = events.first ?? tomorrowEvents.first {
                let eventColor = appViewModel.eventColor(for: next)

                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXT UP")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(eventColor)
                            .tracking(1.2)

                        Text(next.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)

                        Text(headerSubtitle(event: next, at: ctx.date))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No upcoming classes")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headerSubtitle(event: Event, at now: Date) -> String {
        let timeStr = appViewModel.timeString(event.startTime)
        let countdown: String
        if now < event.startTime {
            let m = Int(event.startTime.timeIntervalSince(now) / 60)
            countdown = m < 60 ? "In \(m)m" : "In \(m / 60)h \(m % 60)m"
        } else {
            let m = max(0, Int(event.endTime.timeIntervalSince(now) / 60))
            countdown = "Now · ends in \(m)m"
        }
        let parts = [countdown, timeStr, event.location.isEmpty ? nil : event.location]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    // MARK: - Events list

    private var eventsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !laterToday.isEmpty {
                    sectionLabel("Later Today")
                    ForEach(laterToday) { event in
                        GlassMenuBarRow(event: event)
                            .environmentObject(appViewModel)
                        Divider().opacity(0.15).padding(.leading, 14)
                    }
                }

                if !tomorrowList.isEmpty {
                    sectionLabel(events.isEmpty ? "Tomorrow's Classes" : "Tomorrow")
                    ForEach(tomorrowList.prefix(5)) { event in
                        GlassMenuBarRow(event: event)
                            .environmentObject(appViewModel)
                        Divider().opacity(0.15).padding(.leading, 14)
                    }
                    if tomorrowList.count > 5 {
                        HStack {
                            Text("+\(tomorrowList.count - 5) more")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                }
            }
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { listHeight = geo.size.height }
                    .onChange(of: geo.size.height) { _, h in listHeight = h }
            })
        }
        // A ScrollView in the auto-sized menu bar window collapses to its minimum,
        // so size it to the measured content, capped at 360
        .frame(height: min(max(listHeight, 1), 360))
    }

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView("All Done", systemImage: "moon.stars",
                               description: Text("No more classes today or tomorrow."))
            .frame(height: 150)
    }

    // MARK: - Footer

    private var footerSection: some View {
        GlassEffectContainer {
            HStack(spacing: 8) {
                Button("Open Chronology") {
                    // AppDelegate restores the dock icon and focuses the window; MenuBarLabel recreates it if closed
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }
                .buttonStyle(.glass)

                Button("Settings") {
                    appViewModel.showingSettings = true
                    NotificationCenter.default.post(name: .openMainWindow, object: nil)
                }
                .buttonStyle(.glass)

                Spacer()

                Button {
                    loadTodayEvents(force: true)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .help("Refresh")
            }
        }
        .controlSize(.regular)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Data loading

    private func loadTodayEvents(force: Bool = false) {
        guard let url = appViewModel.activeProfile?.icalUrl, !url.isEmpty else { return }
        isLoading = true
        Task {
            do {
                let allEvents = try await ScheduleService.shared.fetchSchedule(
                    from: url,
                    maxAge: force ? 0 : ScheduleService.defaultMaxAge
                )
                if force { appViewModel.updateMenuBarText() }
                let cal = Calendar.current
                let now = Date()
                let today = cal.startOfDay(for: now)
                let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
                let dayAfter = cal.date(byAdding: .day, value: 2, to: today)!

                let todayRemaining = allEvents.filter {
                    $0.endTime > now && $0.startTime >= today && $0.startTime < tomorrow
                }.sorted { $0.startTime < $1.startTime }

                let tomorrowList = allEvents.filter {
                    $0.startTime >= tomorrow && $0.startTime < dayAfter
                }.sorted { $0.startTime < $1.startTime }

                await MainActor.run {
                    self.events = todayRemaining
                    self.tomorrowEvents = tomorrowList
                    self.isLoading = false
                }
            } catch {
                await MainActor.run { self.isLoading = false }
            }
        }
    }
}

// MARK: - Menu bar event row

struct GlassMenuBarRow: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var isHovering = false

    private var eventColor: Color { appViewModel.eventColor(for: event) }

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(eventColor)
                .frame(width: 3, height: 36)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(appViewModel.timeString(event.startTime))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    if !event.location.isEmpty {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(event.location)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .background(isHovering ? Color.primary.opacity(0.06) : Color.clear, in: .rect(cornerRadius: 8))
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = h }
        }
    }
}
