import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var events: [Event] = []
    @State private var tomorrowEvents: [Event] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Next Up")
                    .font(.headline)
                Spacer()
                if !appViewModel.hideFromDock {
                    Button("Open App") {
                        // Restore dock icon and show window
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                        NotificationCenter.default.post(name: Notification.Name("openMainWindow"), object: nil)
                        if let window = NSApp.windows.first {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            if isLoading {
                ProgressView()
                    .padding()
            } else if events.isEmpty && tomorrowEvents.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "moon.stars")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No more classes today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // Today's remaining events
                        if !events.isEmpty {
                            ForEach(events) { event in
                                MenuBarEventRow(event: event)
                                Divider()
                            }
                        }
                        
                        // Tomorrow's events section
                        if !tomorrowEvents.isEmpty {
                            if !events.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                            
                            HStack {
                                Text(events.isEmpty ? "Tomorrow's Classes" : "Tomorrow")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(nsColor: .windowBackgroundColor))
                            
                            ForEach(tomorrowEvents.prefix(5)) { event in
                                MenuBarEventRow(event: event)
                                Divider()
                            }
                            
                            if tomorrowEvents.count > 5 {
                                HStack {
                                    Text("+\(tomorrowEvents.count - 5) more")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }
            
            Divider()
            
            HStack {
                if appViewModel.hideFromDock {
                    Button("Settings") {
                        NotificationCenter.default.post(name: .openSettings, object: nil)
                        NSApp.setActivationPolicy(.regular) // Temporarily show to access settings
                        NSApp.activate(ignoringOtherApps: true)
                        if let window = NSApp.windows.first {
                            window.makeKeyAndOrderFront(nil)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .font(.caption)
                }
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.caption)
                
                Spacer()
                
                Button(action: {
                    loadTodayEvents()
                    appViewModel.updateMenuBarText()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("Refresh")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 300)
        .onAppear {
            loadTodayEvents()
        }
    }
    
    private func loadTodayEvents() {
        guard let url = appViewModel.activeProfile?.icalUrl, !url.isEmpty else { return }
        
        isLoading = true
        Task {
            do {
                let allEvents = try await ScheduleService.shared.fetchSchedule(from: url)
                
                let calendar = Calendar.current
                let now = Date()
                let today = calendar.startOfDay(for: now)
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
                let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today)!
                
                // Today's remaining events
                let todayEvents = allEvents.filter { event in
                    event.endTime > now &&
                    event.startTime >= today &&
                    event.startTime < tomorrow
                }.sorted { $0.startTime < $1.startTime }
                
                // Tomorrow's events
                let tomorrowEventsList = allEvents.filter { event in
                    event.startTime >= tomorrow &&
                    event.startTime < dayAfterTomorrow
                }.sorted { $0.startTime < $1.startTime }
                
                await MainActor.run {
                    self.events = todayEvents
                    self.tomorrowEvents = tomorrowEventsList
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

struct MenuBarEventRow: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var isHovering = false

    private var eventColor: Color {
        appViewModel.getCustomColor(for: event.title) ?? event.color(from: event.title)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(event.startTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(event.endTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .frame(width: 60, alignment: .trailing)

            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor)
                .frame(width: 3)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                if !event.location.isEmpty {
                    Text(event.location)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovering ? eventColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) { isHovering = hovering }
        }
    }
}
