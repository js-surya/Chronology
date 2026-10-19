import SwiftUI
import ChronologyCore

struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @State private var scheduleViewModel: ScheduleViewModel?
    @State private var searchText = ""
    @State private var isReady = false

    @State private var currentWeekStart: Date = Self.mondayOfCurrentWeek()
    @State private var selectedDay: Date = Date()

    static func mondayOfCurrentWeek() -> Date {
        let cal = Calendar.current
        let now = Date()
        let weekday = cal.component(.weekday, from: now)
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: now) ?? now
        return cal.startOfDay(for: monday)
    }

    private var theme: AppTheme {
        appViewModel.resolvedTheme(for: systemColorScheme)
    }

    var body: some View {
        Group {
            if !isReady {
                ProgressView("Starting Chronology…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appViewModel.profiles.isEmpty || appViewModel.activeProfileId.isEmpty {
                ProfileSelectionView()
                    .environmentObject(appViewModel)
            } else if let vm = scheduleViewModel {
                ScheduleContainerView(
                    vm: vm,
                    searchText: searchText,
                    currentWeekStart: $currentWeekStart,
                    selectedDay: $selectedDay
                )
            } else {
                EmptyStateView()
            }
        }
        .navigationTitle("Chronology")
        .toolbar { toolbarContent }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search Events")
        .preferredColorScheme(theme.preferredColorScheme)
        .background(backgroundForTheme)
        .toolbarBackground(toolbarBackground, for: .windowToolbar)
        .toolbarBackgroundVisibility(theme.isSolid ? .visible : .automatic, for: .windowToolbar)
        .sheet(isPresented: $appViewModel.showingSettings) {
            SettingsView(isPresented: $appViewModel.showingSettings)
                .environmentObject(appViewModel)
        }
        .task {
            appViewModel.ensureInitialized()
            isReady = true
            if !appViewModel.activeProfileId.isEmpty {
                let vm = ScheduleViewModel(appViewModel: appViewModel)
                scheduleViewModel = vm
                Task { await vm.loadSchedule() }
            }
        }
        .onChange(of: appViewModel.activeProfileId) { _, newId in
            if !newId.isEmpty {
                let vm = ScheduleViewModel(appViewModel: appViewModel)
                scheduleViewModel = vm
                Task { await vm.loadSchedule() }
            } else {
                scheduleViewModel = nil
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isReady && !appViewModel.activeProfileId.isEmpty {
            ToolbarItem(placement: .navigation) {
                ProfileMenu(onManageProfiles: {
                    scheduleViewModel = nil
                    appViewModel.activeProfileId = ""
                })
                .environmentObject(appViewModel)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                if let vm = scheduleViewModel { Task { await vm.loadSchedule(force: true) } }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh Schedule (⌘R)")
            .keyboardShortcut("r", modifiers: .command)
            .disabled(scheduleViewModel == nil)
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                appViewModel.showingSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Settings (⌘,)")
        }
    }

    // MARK: - Theme surfaces

    @ViewBuilder
    private var backgroundForTheme: some View {
        switch theme {
        case .light, .dark: Color.clear
        case .darkSolid:    Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1))
        case .amoled:       Color.black
        }
    }

    private var toolbarBackground: AnyShapeStyle {
        switch theme {
        case .amoled:    AnyShapeStyle(Color.black)
        case .darkSolid: AnyShapeStyle(Color(nsColor: NSColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 1)))
        default:         AnyShapeStyle(.clear) // system Liquid Glass toolbar
        }
    }
}

// MARK: - Profile menu

struct ProfileMenu: View {
    @EnvironmentObject var appViewModel: AppViewModel
    let onManageProfiles: () -> Void

    var body: some View {
        if let profile = appViewModel.activeProfile {
            Menu {
                Picker("Profile", selection: Binding(
                    get: { appViewModel.activeProfileId },
                    set: { id in
                        if let p = appViewModel.profiles.first(where: { $0.id.uuidString == id }) {
                            appViewModel.switchToProfile(p)
                        }
                    }
                )) {
                    ForEach(appViewModel.profiles) { p in
                        Text(p.name).tag(p.id.uuidString)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Divider()
                Button("Manage Profiles…", action: onManageProfiles)
            } label: {
                Label {
                    Text(profile.name)
                } icon: {
                    profileIcon(profile)
                }
                .labelStyle(.titleAndIcon)
            }
            .help("Switch Profile")
        }
    }

    @ViewBuilder
    private func profileIcon(_ profile: ScheduleProfile) -> some View {
        if profile.emoji.allSatisfy({ $0.isASCII }) {
            Image(systemName: profile.emoji)
                .foregroundStyle(profile.emojiColor?.color ?? appViewModel.accentColor)
        } else {
            Text(profile.emoji)
        }
    }
}

// MARK: - Schedule container

struct ScheduleContainerView: View {
    @ObservedObject var vm: ScheduleViewModel
    let searchText: String
    @EnvironmentObject var appViewModel: AppViewModel
    @Binding var currentWeekStart: Date
    @Binding var selectedDay: Date

    var body: some View {
        if vm.isLoading && vm.events.isEmpty {
            ProgressView("Loading Schedule…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load Schedule", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { Task { await vm.loadSchedule(force: true) } }
                    .buttonStyle(.glassProminent)
            }
            .navigationSubtitle(appViewModel.activeProfile?.name ?? "")
        } else if vm.events.isEmpty {
            ContentUnavailableView {
                Label("No Events", systemImage: "calendar")
            } description: {
                Text(appViewModel.activeProfileUrl.isEmpty
                     ? "This profile has no calendar link."
                     : "This calendar is empty. If the term ended, copy a new iCal link from TimeEdit.")
            } actions: {
                Button("Refresh") { Task { await vm.loadSchedule(force: true) } }
                    .buttonStyle(.glass)
            }
            .navigationSubtitle(appViewModel.activeProfile?.name ?? "")
        } else {
            HStack(spacing: 0) {
                LeftRailView(events: vm.events)
                    .environmentObject(appViewModel)

                Divider()

                Group {
                    if appViewModel.viewMode == "day" {
                        DayView(
                            events: vm.filteredEvents(searchText: searchText),
                            selectedDate: $selectedDay
                        )
                    } else {
                        WeekGridView(
                            events: vm.filteredEvents(searchText: searchText),
                            currentWeekStart: $currentWeekStart
                        )
                    }
                }
                .environmentObject(appViewModel)
                .overlay {
                    if !searchText.isEmpty && vm.filteredEvents(searchText: searchText).isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            // Only a loaded schedule gets period controls; loading/error/empty states don't
            .modifier(PeriodNavigation(currentWeekStart: $currentWeekStart, selectedDay: $selectedDay))
        }
    }
}

// MARK: - Period navigation

/// Day/Week switch, ‹ Today › and the date-range window title.
struct PeriodNavigation: ViewModifier {
    @EnvironmentObject var appViewModel: AppViewModel
    @Binding var currentWeekStart: Date
    @Binding var selectedDay: Date

    func body(content: Content) -> some View {
        content
            // Window title carries the date range, like Calendar; the profile goes in the subtitle
            .navigationTitle(periodTitle)
            .navigationSubtitle(periodSubtitle)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $appViewModel.viewMode) {
                        Text("Day").tag("day")
                        Text("Week").tag("week")
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .help("Switch between Day and Week (⌘1 / ⌘2)")
                }

                // Centre cluster beside the Day/Week switch, so the window's own actions stay at the trailing edge
                ToolbarItem(placement: .principal) {
                    ControlGroup {
                        Button { navigate(by: -1) } label: {
                            Label(isWeek ? "Previous Week" : "Previous Day", systemImage: "chevron.left")
                        }
                        .keyboardShortcut(.leftArrow, modifiers: .command)
                        Button("Today", action: goToToday)
                            .keyboardShortcut("t", modifiers: .command)
                        Button { navigate(by: 1) } label: {
                            Label(isWeek ? "Next Week" : "Next Day", systemImage: "chevron.right")
                        }
                        .keyboardShortcut(.rightArrow, modifiers: .command)
                    }
                    .controlGroupStyle(.navigation)
                }
            }
    }

    private var isWeek: Bool { appViewModel.viewMode == "week" }

    private func goToToday() {
        if isWeek {
            currentWeekStart = ContentView.mondayOfCurrentWeek()
        } else {
            selectedDay = Date()
        }
    }

    private func navigate(by n: Int) {
        let cal = Calendar.current
        if isWeek {
            if let d = cal.date(byAdding: .weekOfYear, value: n, to: currentWeekStart) {
                currentWeekStart = d
            }
        } else if let d = cal.date(byAdding: .day, value: n, to: selectedDay) {
            selectedDay = d
        }
    }

    private var periodTitle: String {
        if isWeek {
            let end = Calendar.current.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
            let sameMonth = Calendar.current.isDate(currentWeekStart, equalTo: end, toGranularity: .month)
            let start = currentWeekStart.formatted(sameMonth ? .dateTime.day() : .dateTime.day().month(.abbreviated))
            return "\(start) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
        }
        return selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var periodSubtitle: String {
        let profile = appViewModel.activeProfile?.name ?? ""
        if isWeek {
            let week = Calendar(identifier: .iso8601).component(.weekOfYear, from: currentWeekStart)
            return profile.isEmpty ? "Week \(week)" : "Week \(week) · \(profile)"
        }
        return profile
    }
}

// MARK: - Left rail

struct LeftRailView: View {
    let events: [Event]
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        // Re-evaluated every minute so "Next Up" and "Today" roll over without a reload
        TimelineView(.everyMinute) { ctx in
            let now = ctx.date
            let upcoming = events.filter { !$0.isAllDay && $0.endTime > now }.sorted { $0.startTime < $1.startTime }
            let today = upcoming.filter { Calendar.current.isDateInToday($0.startTime) }
            let important = upcoming.filter { appViewModel.isEventImportant($0) }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let next = upcoming.first {
                        NextUpCard(event: next, now: now)
                    }

                    if !today.isEmpty {
                        railSection("Today") {
                            ForEach(today.prefix(8)) { RailEventRow(event: $0) }
                        }
                    }

                    if !important.isEmpty {
                        railSection("Important") {
                            ForEach(important.prefix(8)) { RailEventRow(event: $0, showsDate: true) }
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 240)
        .scrollContentBackground(.hidden)
    }

    private func railSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionCaption(text: title)
                .padding(.horizontal, 6)
            content()
        }
    }
}

struct NextUpCard: View {
    let event: Event
    let now: Date
    @EnvironmentObject var appViewModel: AppViewModel

    private var color: Color { appViewModel.eventColor(for: event) }
    private var inProgress: Bool { event.startTime <= now }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(inProgress ? "NOW" : "NEXT UP")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(color)

            Text(event.title)
                .font(.headline)
                .lineLimit(2)

            VStack(alignment: .leading, spacing: 3) {
                Label(appViewModel.timeRange(event), systemImage: "clock")
                    .monospacedDigit()
                if !event.location.isEmpty {
                    Label(event.location, systemImage: "mappin.and.ellipse")
                        .lineLimit(1)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .labelStyle(RailLabelStyle())

            Text(countdown)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(color.opacity(0.25)), in: .rect(cornerRadius: ChronoTokens.panelRadius))
        .accessibilityElement(children: .combine)
    }

    private var countdown: String {
        let target = inProgress ? event.endTime : event.startTime
        let minutes = max(0, Int(target.timeIntervalSince(now) / 60))
        let span = minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
        return inProgress ? "Ends in \(span)" : "In \(span)"
    }
}

/// Compact icon + text for the rail, with icons aligned in a fixed column.
private struct RailLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.frame(width: 12)
            configuration.title
        }
    }
}

struct RailEventRow: View {
    let event: Event
    var showsDate: Bool = false
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var isHovering = false
    @State private var showingDetail = false

    var body: some View {
        Button { showingDetail = true } label: {
            HStack(spacing: 8) {
                Capsule()
                    .fill(appViewModel.eventColor(for: event))
                    .frame(width: 3, height: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if appViewModel.isEventImportant(event) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(isHovering ? 0.06 : 0), in: .rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .popover(isPresented: $showingDetail, arrowEdge: .trailing) {
            EventDetailPopover(event: event)
                .environmentObject(appViewModel)
        }
    }

    private var detail: String {
        var parts: [String] = []
        if showsDate { parts.append(event.startTime.formatted(.dateTime.weekday(.abbreviated).day())) }
        parts.append(appViewModel.timeString(event.startTime))
        if !event.location.isEmpty { parts.append(event.location) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    @EnvironmentObject var appViewModel: AppViewModel

    var body: some View {
        ContentUnavailableView {
            Label("No Schedule", systemImage: "calendar.badge.plus")
        } description: {
            Text("Add your TimeEdit iCal link in Settings to get started.")
        } actions: {
            Button("Open Settings") { appViewModel.showingSettings = true }
                .buttonStyle(.glassProminent)
        }
    }
}
