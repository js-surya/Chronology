import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var events: [Event] = []
    @State private var tomorrowEvents: [Event] = []
    @State private var isLoading = false

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
            } else {
                eventsList
                Divider().opacity(0.25)
            }

            footerSection
        }
        .frame(width: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear { loadTodayEvents() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = events.first ?? tomorrowEvents.first {
                let eventColor = appViewModel.getCustomColor(for: next.title) ?? next.color(from: next.title)

                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NEXT UP")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(eventColor)
                            .tracking(1.2)

                        Text(next.title)
                            .font(.system(size: 19, weight: .semibold))
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
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        let timeStr = fmt.string(from: event.startTime)
        let countdown: String
        if now < event.startTime {
            let interval = event.startTime.timeIntervalSince(now)
            let m = Int(interval / 60)
            countdown = m < 60 ? "In \(m)m" : "In \(m / 60)h \(m % 60)m"
        } else {
            countdown = "Now"
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
                if !events.isEmpty {
                    sectionLabel("Later Today")
                    ForEach(events) { event in
                        GlassMenuBarRow(event: event)
                            .environmentObject(appViewModel)
                        Divider().opacity(0.15).padding(.leading, 14)
                    }
                }

                if !tomorrowEvents.isEmpty {
                    sectionLabel(events.isEmpty ? "Tomorrow's Classes" : "Tomorrow")
                    ForEach(tomorrowEvents.prefix(5)) { event in
                        GlassMenuBarRow(event: event)
                            .environmentObject(appViewModel)
                        Divider().opacity(0.15).padding(.leading, 14)
                    }
                    if tomorrowEvents.count > 5 {
                        HStack {
                            Text("+\(tomorrowEvents.count - 5) more")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .frame(maxHeight: 360)
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
        VStack(spacing: 10) {
            Image(systemName: "moon.stars")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No more classes today")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: 10) {
            Button("Open Chronology") {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: Notification.Name("openMainWindow"), object: nil)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(MenuBarCapsuleStyle())

            Button("Settings") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(MenuBarCapsuleStyle())

            Spacer()

            Button {
                loadTodayEvents()
                appViewModel.updateMenuBarText()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Data loading

    private func loadTodayEvents() {
        guard let url = appViewModel.activeProfile?.icalUrl, !url.isEmpty else { return }
        isLoading = true
        Task {
            do {
                let allEvents = try await ScheduleService.shared.fetchSchedule(from: url)
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

    private var eventColor: Color {
        appViewModel.getCustomColor(for: event.title) ?? event.color(from: event.title)
    }

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
                    Text(event.startTime.formatted(date: .omitted, time: .shortened))
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
        .background(isHovering ? Color.primary.opacity(0.04) : Color.clear)
        .contentShape(Rectangle())
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = h }
        }
    }
}

// MARK: - Liquid glass capsule button style for menu bar

struct MenuBarCapsuleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.2), value: configuration.isPressed)
    }
}
