import SwiftUI

struct WeekGridView: View {
    let events: [Event]
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    
    @State private var currentWeekStart = Date()
    @State private var layouts: [EventLayout] = []
    @State private var viewWidth: CGFloat = 0
    @State private var isDatePickerPresented = false
    
    @AppStorage("use24HourFormat") private var use24HourFormat = true
    @AppStorage("startHour") private var startHour = 8
    @AppStorage("endHour") private var endHour = 20
    @AppStorage("themeMode") private var themeMode = "auto"
    @AppStorage("preferredDarkMode") private var preferredDarkMode = "dark"
    
    private var isAmoledTheme: Bool {
        if themeMode == "amoled" {
            return true
        }
        if themeMode == "auto" && preferredDarkMode == "amoled" {
            return systemColorScheme == .dark
        }
        return false
    }
    
    private let hourHeight: CGFloat = 60
    private let timeColumnWidth: CGFloat = 60
    
    var body: some View {
        VStack(spacing: 0) {
            // Week navigation header
            weekHeader
            Divider()
            
            // Calendar grid
            GeometryReader { geometry in
                ScrollView {
                    calendarGrid(width: geometry.size.width)
                }
                .onAppear {
                    viewWidth = geometry.size.width
                    initializeWeek()
                    calculateLayout()
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    viewWidth = newWidth
                    calculateLayout()
                }
                .onChange(of: currentWeekStart) { _, _ in
                    calculateLayout()
                }
                .onChange(of: events.count) { _, _ in
                    calculateLayout()
                }
            }
        }
        .background(isAmoledTheme ? Color.black : Color.clear)
    }
    
    // MARK: - Header
    
    private var weekHeader: some View {
        ZStack {
            HStack {
                Button("Today") { initializeWeek() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
            }

            HStack(spacing: 6) {
                Button { moveWeek(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("Previous week")

                Button { isDatePickerPresented.toggle() } label: {
                    HStack(spacing: 4) {
                        Text(weekTitle).font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isDatePickerPresented) {
                    DatePicker("", selection: Binding(
                        get: { currentWeekStart },
                        set: { newDate in
                            let calendar = Calendar.current
                            let weekday = calendar.component(.weekday, from: newDate)
                            let daysFromMonday = (weekday + 5) % 7
                            if let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: newDate) {
                                currentWeekStart = calendar.startOfDay(for: monday)
                            }
                        }
                    ), displayedComponents: [.date])
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(8)
                }

                Button { moveWeek(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .help("Next week")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isAmoledTheme ? AnyShapeStyle(Color.black) : AnyShapeStyle(.regularMaterial))
    }
    
    // MARK: - Calendar Grid
    
    private func calendarGrid(width: CGFloat) -> some View {
        let dayWidth = (width - timeColumnWidth) / 7
        
        return ZStack(alignment: .topLeading) {
            // Background grid
            VStack(spacing: 0) {
                dayHeaders(dayWidth: dayWidth)
                timeGrid
            }
            
            // Day separators
            daySeparators(dayWidth: dayWidth)
            
            // Events
            eventViews(dayWidth: dayWidth)
            
            // Current time indicator
            if isCurrentWeek {
                currentTimeIndicator(width: width)
            }
        }
        .frame(height: CGFloat(endHour - startHour + 1) * hourHeight + 50)
    }
    
    private func dayHeaders(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth)

            ForEach(0..<7) { dayOffset in
                if let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: currentWeekStart) {
                    let isToday = Calendar.current.isDateInToday(date)
                    VStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(isToday ? appViewModel.accentColor : .secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(isToday ? .white : .primary)
                            .frame(width: 26, height: 26)
                            .background(
                                Circle()
                                    .fill(isToday ? appViewModel.accentColor : Color.clear)
                            )
                    }
                    .frame(width: dayWidth)
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.bottom, 4)
    }
    
    private var timeGrid: some View {
        ForEach(startHour...endHour, id: \.self) { hour in
            HStack(spacing: 0) {
                Text(formatHour(hour))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.trailing, 8)
                    .offset(y: -8)
                
                Rectangle()
                    .fill(Color.primary.opacity(appViewModel.gridLineOpacity))
                    .frame(height: appViewModel.gridLineThickness)
            }
            .frame(height: hourHeight, alignment: .top)
        }
    }
    
    private func daySeparators(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth)
            ForEach(0..<7) { dayIndex in
                Rectangle()
                    .fill(Color.primary.opacity(appViewModel.gridLineOpacity))
                    .frame(width: appViewModel.gridLineThickness)
                    .frame(width: dayWidth, alignment: .leading)
                    .background(
                        // Apply background to each day column
                        Color.clear.frame(width: dayWidth)
                    )
            }
        }
        .offset(y: 40)
    }
    
    private func eventViews(dayWidth: CGFloat) -> some View {
        ForEach(layouts) { layout in
            EventItemView(event: layout.event)
                .frame(width: layout.rect.width, height: layout.rect.height)
                .position(x: layout.rect.origin.x, y: layout.rect.origin.y + 40)
        }
    }
    
    // MARK: - Layout Calculation
    
    private func calculateLayout() {
        guard viewWidth > 0 else { return }
        
        let dayWidth = (viewWidth - timeColumnWidth) / 7
        let weekEvents = eventsInCurrentWeek
        
        layouts = WeekViewLayoutEngine.calculateLayout(
            for: weekEvents,
            startHour: startHour,
            endHour: endHour,
            dayWidth: dayWidth,
            timeColumnWidth: timeColumnWidth,
            hourHeight: hourHeight
        )
    }
    
    // MARK: - Helpers
    
    private func initializeWeek() {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let daysFromMonday = (weekday + 5) % 7
        if let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: now) {
            currentWeekStart = calendar.startOfDay(for: monday)
        }
    }
    
    private func moveWeek(by weeks: Int) {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: currentWeekStart) {
            currentWeekStart = newDate
        }
    }
    
    private var weekTitle: String {
        let calendar = Calendar.current
        let endOfWeek = calendar.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        // Get week number (ISO 8601 week number)
        let weekNumber = calendar.component(.weekOfYear, from: currentWeekStart)
        
        return "Week \(weekNumber) • \(formatter.string(from: currentWeekStart)) - \(formatter.string(from: endOfWeek))"
    }
    
    private var eventsInCurrentWeek: [Event] {
        let calendar = Calendar.current
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        return events.filter { $0.startTime >= currentWeekStart && $0.startTime < endOfWeek }
    }
    
    private var isCurrentWeek: Bool {
        let calendar = Calendar.current
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        return now >= currentWeekStart && now < endOfWeek
    }
    
    private func getYPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        let timeOffset = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return timeOffset * hourHeight
    }
    
    private func currentTimeIndicator(width: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60.0)) { context in
            let yPos = getYPosition(for: context.date)
            let hour = Calendar.current.component(.hour, from: context.date)

            if hour >= startHour && hour <= endHour {
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        Spacer().frame(width: timeColumnWidth)
                        Rectangle()
                            .fill(appViewModel.accentColor.opacity(0.55))
                            .frame(height: 1)
                    }

                    HStack(spacing: 0) {
                        HStack(spacing: 3) {
                            Text(context.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2).fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(appViewModel.accentColor)
                        )
                        .frame(width: timeColumnWidth - 4, alignment: .trailing)

                        Circle()
                            .fill(appViewModel.accentColor)
                            .frame(width: 7, height: 7)
                            .offset(x: -3)
                    }
                }
                .offset(y: yPos + 40)
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        if use24HourFormat {
            return String(format: "%02d:00", hour)
        } else {
            let period = hour < 12 ? "AM" : "PM"
            let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
            return "\(displayHour) \(period)"
        }
    }
}

// MARK: - Event Item View

struct EventItemView: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingDetail = false
    @State private var isHovering = false
    
    private let hourHeight: CGFloat = 60
    
    private var eventColor: Color {
        appViewModel.getCustomColor(for: event.title) ?? event.color(from: event.title)
    }

    private var textColorForFill: Color {
        guard let ns = NSColor(eventColor).usingColorSpace(.deviceRGB) else { return .white }
        let lum = 0.299 * ns.redComponent + 0.587 * ns.greenComponent + 0.114 * ns.blueComponent
        return lum > 0.65 ? Color(white: 0.15) : .white
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var isImportant: Bool {
        appViewModel.isEventImportant(event)
    }
    
    private func toggleImportant() {
        if isImportant {
            // Remove important event - match by title and exact start time
            appViewModel.importantEvents.removeAll { $0.eventTitle == event.title && abs($0.eventDate.timeIntervalSince(event.startTime)) < 60 }
            appViewModel.saveImportantEvents()
        } else {
            // Add important event with default 15 min reminder
            let importantEvent = ImportantEvent(
                eventTitle: event.title,
                eventDate: event.startTime,
                reminderMinutes: 15
            )
            appViewModel.importantEvents.append(importantEvent)
            appViewModel.saveImportantEvents()
            
            // Reschedule notifications
            NotificationCenter.default.post(name: .rescheduleNotifications, object: nil)
        }
    }
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        if appViewModel.showEventIcons {
                            Image(systemName: getEventIcon())
                                .font(.caption2)
                                .foregroundColor(textColor.opacity(0.85))
                        }

                        Text(event.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        Spacer()

                        if isHovering || isImportant {
                            Button {
                                toggleImportant()
                            } label: {
                                Image(systemName: isImportant ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(isImportant ? .yellow : textColor.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .help(isImportant ? "Remove important reminder" : "Mark as important")
                        }

                        if appViewModel.getNote(for: event) != nil {
                            Image(systemName: "note.text")
                                .font(.caption2)
                                .foregroundColor(textColor.opacity(0.75))
                        }
                    }
                    if !event.location.isEmpty {
                        HStack(spacing: 2) {
                            if appViewModel.showEventIcons {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(textColor.opacity(0.7))
                            }
                            Text(event.location)
                                .font(.caption2)
                                .foregroundColor(textColor.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                
                // Hover time overlay
                if isHovering && !isImportant {
                    Text(formatTimeRange())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                        .padding(4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .background(cardBackground())
            .cornerRadius(appViewModel.eventCornerRadius)
            .overlay(cardOverlay())
            .overlay(accentBar, alignment: .leading)
            .foregroundColor(textColor)
            .shadow(color: .black.opacity(appViewModel.eventShadowEnabled ? 0.15 : 0),
                   radius: isHovering ? 4 : 2)
            .scaleEffect(isHovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $showingDetail) {
            EventDetailPopover(event: event)
                .environmentObject(appViewModel)
        }
    }
    
    private var textColor: Color {
        switch appViewModel.eventCardStyle {
        case "filled": return textColorForFill
        default: return .primary
        }
    }

    @ViewBuilder
    private func cardBackground() -> some View {
        switch appViewModel.eventCardStyle {
        case "filled":
            eventColor.opacity(0.9)
        case "bordered":
            Color.clear
        case "minimal":
            eventColor.opacity(0.15)
        default:
            eventColor.opacity(0.9)
        }
    }

    @ViewBuilder
    private func cardOverlay() -> some View {
        RoundedRectangle(cornerRadius: appViewModel.eventCornerRadius)
            .stroke(eventColor, lineWidth: appViewModel.eventBorderWidth)
    }

    @ViewBuilder
    private var accentBar: some View {
        if appViewModel.eventCardStyle == "minimal" {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(eventColor)
                .frame(width: 3)
                .padding(.vertical, 4)
                .padding(.leading, 2)
        } else {
            EmptyView()
        }
    }
    
    private func getEventIcon() -> String {
        // Check description first (more accurate), fallback to title
        let searchText = (event.description?.lowercased() ?? "") + " " + event.title.lowercased()
        
        if searchText.contains("lab") || searchText.contains("practical") {
            return "flask.fill"
        } else if searchText.contains("lecture") || searchText.contains("class") {
            return "book.fill"
        } else if searchText.contains("exam") || searchText.contains("test") {
            return "doc.text.fill"
        } else if searchText.contains("tutorial") || searchText.contains("seminar") {
            return "person.2.fill"
        } else if searchText.contains("project") {
            return "hammer.fill"
        } else {
            return "calendar"
        }
    }
    
    private func formatTimeRange() -> String {
        let startTime = timeFormatter.string(from: event.startTime)
        let endTime = timeFormatter.string(from: event.endTime)
        return "\(startTime) - \(endTime)"
    }
}
