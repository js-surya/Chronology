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
        HStack {
            Button("Today") {
                initializeWeek()
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Button(action: { moveWeek(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            
            Button(action: { isDatePickerPresented.toggle() }) {
                HStack(spacing: 4) {
                    Text(weekTitle)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isDatePickerPresented) {
                DatePicker("Select Date", selection: Binding(
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
                .padding()
            }
            
            Button(action: { moveWeek(by: 1) }) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Invisible spacer to balance the "Today" button
            Text("Today").opacity(0).accessibilityHidden(true)
        }
        .padding()
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
                    VStack(spacing: 2) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(date.formatted(.dateTime.day()))
                            .font(.caption2)
                    }
                    .frame(width: dayWidth)
                    .padding(.vertical, 8)
                    .background(Calendar.current.isDateInToday(date) ? appViewModel.accentColor.opacity(0.15) : Color.clear)
                    .cornerRadius(6)
                }
            }
        }
        .padding(.bottom, 8)
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
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
            }
            .frame(height: hourHeight, alignment: .top)
        }
    }
    
    private func daySeparators(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth)
            ForEach(0..<7) { _ in
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 1)
                    .frame(width: dayWidth, alignment: .leading)
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
                HStack(spacing: 0) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(context.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(appViewModel.accentColor)
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.trailing, 4)
                    .background(isAmoledTheme ? Color.black.opacity(0.8) : Color.white.opacity(0.8))
                    
                    Circle()
                        .fill(appViewModel.accentColor)
                        .frame(width: 6, height: 6)
                        .offset(x: -3)
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
                        Text(event.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        Spacer()
                        
                        // Important star button (visible on hover or when important)
                        if isHovering || isImportant {
                            Button {
                                toggleImportant()
                            } label: {
                                Image(systemName: isImportant ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(isImportant ? .yellow : .white.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help(isImportant ? "Remove important reminder" : "Mark as important")
                        }
                        
                        if appViewModel.getNote(for: event) != nil {
                            Image(systemName: "note.text")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    if !event.location.isEmpty {
                        Text(event.location)
                            .font(.caption2)
                            .lineLimit(1)
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
            .background(eventColor.opacity(0.9))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(eventColor, lineWidth: 1.5)
            )
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.15), radius: isHovering ? 4 : 2)
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
    
    private func formatTimeRange() -> String {
        let startTime = timeFormatter.string(from: event.startTime)
        let endTime = timeFormatter.string(from: event.endTime)
        return "\(startTime) - \(endTime)"
    }
}
