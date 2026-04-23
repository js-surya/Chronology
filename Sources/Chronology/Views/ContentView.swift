import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @State private var scheduleViewModel: ScheduleViewModel?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var isReady = false
    @State private var currentDayIcon = "\(Calendar.current.component(.day, from: Date())).square"

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
                ProgressView("Starting Chronology...")
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
                EmptyStateView(showingSettings: $showingSettings)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                if isReady {
                    CapsuleSegmentedControl(selection: $appViewModel.viewMode)
                }
                if isReady && !appViewModel.activeProfileId.isEmpty {
                    ProfileMenuPill(onClearProfile: {
                        scheduleViewModel = nil
                        appViewModel.activeProfileId = ""
                    })
                    .environmentObject(appViewModel)
                }
            }

            ToolbarItem(placement: .principal) {
                if isReady && scheduleViewModel != nil {
                    NavigationCluster(
                        viewMode: appViewModel.viewMode,
                        currentWeekStart: $currentWeekStart,
                        selectedDay: $selectedDay,
                        accentColor: appViewModel.accentColor
                    )
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                IconCircleButton(systemName: "arrow.clockwise", help: "Refresh Schedule") {
                    if let vm = scheduleViewModel { Task { await vm.loadSchedule() } }
                }
                .disabled(scheduleViewModel == nil)

                IconCircleButton(systemName: "gear", help: "Settings") {
                    showingSettings.toggle()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search events...")
        .preferredColorScheme(theme.preferredColorScheme)
        .background(backgroundForTheme)
        .toolbarBackground(toolbarBackground, for: .windowToolbar)
        .sheet(isPresented: $showingSettings) {
            SettingsView(isPresented: $showingSettings)
                .environmentObject(appViewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            showingSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            currentDayIcon = "\(Calendar.current.component(.day, from: Date())).square"
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
        default:         AnyShapeStyle(.regularMaterial)
        }
    }
}

// MARK: - Toolbar controls

struct CapsuleSegmentedControl: View {
    @Binding var selection: String

    var body: some View {
        GlassSegmented(
            selection: $selection,
            options: [
                ("week", "Week", "calendar"),
                ("day",  "Day",  "doc.text")
            ]
        )
    }
}

struct ProfileMenuPill: View {
    @EnvironmentObject var appViewModel: AppViewModel
    let onClearProfile: () -> Void

    var body: some View {
        if let profile = appViewModel.activeProfile {
            Menu {
                Section {
                    ForEach(appViewModel.profiles) { p in
                        Button {
                            appViewModel.switchToProfile(p)
                        } label: {
                            if appViewModel.activeProfileId == p.id.uuidString {
                                Label(p.name, systemImage: "checkmark")
                            } else {
                                Text(p.name)
                            }
                        }
                    }
                }
                Divider()
                Button("Manage Profiles", action: onClearProfile)
            } label: {
                HStack(spacing: 6) {
                    profileBadge(profile)
                    Text(profile.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Switch Profile")
        }
    }

    @ViewBuilder
    private func profileBadge(_ profile: ScheduleProfile) -> some View {
        let color = profile.emojiColor?.color ?? appViewModel.accentColor
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 20, height: 20)
            if profile.emoji.allSatisfy({ $0.isASCII }) {
                Image(systemName: profile.emoji)
                    .font(.system(size: 10))
                    .foregroundColor(color)
            } else {
                Text(profile.emoji).font(.system(size: 11))
            }
        }
    }
}

struct NavigationCluster: View {
    let viewMode: String
    @Binding var currentWeekStart: Date
    @Binding var selectedDay: Date
    let accentColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Button("Today") { goToToday() }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .overlay(Capsule().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                .buttonStyle(.plain)

            HStack(spacing: 4) {
                Button { navigate(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)

                Text(navigationTitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .fixedSize()

                Button { navigate(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func goToToday() {
        if viewMode == "week" {
            currentWeekStart = ContentView.mondayOfCurrentWeek()
        } else {
            selectedDay = Date()
        }
    }

    private func navigate(by n: Int) {
        let cal = Calendar.current
        if viewMode == "week" {
            if let d = cal.date(byAdding: .weekOfYear, value: n, to: currentWeekStart) {
                currentWeekStart = d
            }
        } else {
            if let d = cal.date(byAdding: .day, value: n, to: selectedDay) {
                selectedDay = d
            }
        }
    }

    private var navigationTitle: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        if viewMode == "week" {
            let end = cal.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
            fmt.dateFormat = "d MMM"
            let wk = cal.component(.weekOfYear, from: currentWeekStart)
            let yr = cal.component(.year, from: currentWeekStart)
            return "\(fmt.string(from: currentWeekStart))–\(fmt.string(from: end)) \(yr) · wk \(wk)"
        } else {
            fmt.dateFormat = "EEE, d MMM yyyy"
            return fmt.string(from: selectedDay)
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
        if vm.isLoading {
            ProgressView("Loading schedule…")
                .controlSize(.regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = vm.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 44, weight: .light))
                    .foregroundColor(.orange)
                Text("Couldn't load schedule")
                    .font(.title3).fontWeight(.semibold)
                Text(error)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button { Task { await vm.loadSchedule() } } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.events.isEmpty {
            if appViewModel.activeProfileUrl.isEmpty {
                Text("No URL configured").foregroundColor(.secondary)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(.secondary.opacity(0.8))
                    Text("No Events")
                        .font(.title3).fontWeight(.semibold)
                    Text("Your schedule is empty or still syncing.")
                        .font(.callout).foregroundColor(.secondary)
                    Button { Task { await vm.loadSchedule() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            HStack(spacing: 0) {
                LeftRailView(events: vm.events)
                    .environmentObject(appViewModel)

                Divider()

                if appViewModel.viewMode == "day" {
                    DayView(
                        events: vm.filteredEvents(searchText: searchText),
                        selectedDate: $selectedDay
                    )
                    .environmentObject(appViewModel)
                } else {
                    WeekGridView(
                        events: vm.filteredEvents(searchText: searchText),
                        currentWeekStart: $currentWeekStart
                    )
                    .environmentObject(appViewModel)
                }
            }
        }
    }
}

// MARK: - Left rail

struct LeftRailView: View {
    let events: [Event]
    @EnvironmentObject var appViewModel: AppViewModel

    private var now: Date { Date() }

    private var nextEvent: Event? {
        events.filter { $0.endTime > now }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    private var todayRemainingEvents: [Event] {
        let cal = Calendar.current
        return events
            .filter { cal.isDateInToday($0.startTime) && $0.endTime > now }
            .sorted { $0.startTime < $1.startTime }
    }

    private var importantUpcoming: [Event] {
        events
            .filter { appViewModel.isEventImportant($0) && $0.endTime > now }
            .sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let next = nextEvent {
                    NextUpCard(event: next)
                }

                if !todayRemainingEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)

                        ForEach(todayRemainingEvents.prefix(8)) { event in
                            TodayMiniRow(event: event)
                        }
                    }
                }

                if !importantUpcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("IMPORTANT", systemImage: "star.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(1.2)

                        ForEach(importantUpcoming) { event in
                            ImportantMiniRow(event: event)
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(12)
        }
        .frame(width: 240)
        .background(Color.primary.opacity(0.025))
    }
}

struct NextUpCard: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var colorScheme

    private var hue: Double { hueForCourse(event.title) }
    private var theme: AppTheme { appViewModel.resolvedTheme(for: colorScheme) }

    var body: some View {
        let isDark = theme != .light
        ZStack {
            RoundedRectangle(cornerRadius: ChronoTokens.panelRadius)
                .fill(LinearGradient(
                    colors: [
                        Color(hue: hue/360, saturation: 0.45,
                              brightness: isDark ? 0.55 : 0.90).opacity(0.7),
                        Color(hue: hue/360, saturation: 0.50,
                              brightness: isDark ? 0.45 : 0.80).opacity(0.25)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .background(
                    Group {
                        if theme.isTranslucent {
                            RoundedRectangle(cornerRadius: ChronoTokens.panelRadius)
                                .fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(RoundedRectangle(cornerRadius: ChronoTokens.panelRadius)
                    .strokeBorder(.white.opacity(theme.isTranslucent ? 0.5 : 0.1), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 6) {
                SectionCaption(text: "Next Up")
                    .foregroundStyle(Color.eventHeader(hue: hue))
                Text(event.title)
                    .font(.system(size: 16, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.system(size: 10))
                    Text("\(fmt(event.startTime)) – \(fmt(event.endTime))")
                        .monospacedDigit()
                }
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
                if !event.location.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin").font(.system(size: 10))
                        Text(event.location)
                    }
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    Text(countdown(to: event.startTime, now: ctx.date))
                        .font(.system(size: 24, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.eventHeader(hue: hue))
                        .padding(.top, 4)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func fmt(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: d)
    }
    private func countdown(to d: Date, now: Date) -> String {
        let s = max(0, Int(d.timeIntervalSince(now)))
        if s < 3600 { return "In \(s / 60)m" }
        return "In \(s / 3600)h \((s % 3600) / 60)m"
    }
}

struct TodayMiniRow: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel

    private var eventColor: Color {
        appViewModel.getCustomColor(for: event.title) ?? event.color(from: event.title)
    }

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(eventColor)
                .frame(width: 3, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(event.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    if !event.location.isEmpty {
                        Text("·")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text(event.location)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
    }
}

struct ImportantMiniRow: View {
    let event: Event

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)
            Text(event.title)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
            Spacer()
        }
    }
}

// MARK: - Empty state

struct EmptyStateView: View {
    @Binding var showingSettings: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.secondary.opacity(0.8))

            Text("No Schedule Configured")
                .font(.title3).fontWeight(.semibold)

            Text("Add your TimeEdit iCal URL in settings to get started.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showingSettings = true
            } label: {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
