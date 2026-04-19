import SwiftUI

struct DayView: View {
    let events: [Event]
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    
    @State private var selectedDate = Date()
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
    
    private let hourHeight: CGFloat = 80
    private let timeColumnWidth: CGFloat = 70
    
    var body: some View {
        VStack(spacing: 0) {
            // Date navigation header
            dateHeader
            Divider()
            
            // Day grid
            GeometryReader { geometry in
                ScrollView {
                    dayGrid(width: geometry.size.width)
                        .padding(.top, 15)
                }
                .onAppear {
                    viewWidth = geometry.size.width
                    calculateLayout()
                }
                .onChange(of: geometry.size.width) { _, newWidth in
                    viewWidth = newWidth
                    calculateLayout()
                }
                .onChange(of: selectedDate) { _, _ in
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
    
    private var dateHeader: some View {
        ZStack {
            HStack {
                Button("Today") { selectedDate = Date() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Spacer()
            }

            HStack(spacing: 6) {
                Button { moveDay(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("Previous day")

                Button { isDatePickerPresented.toggle() } label: {
                    HStack(spacing: 4) {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide))
                             + ", "
                             + selectedDate.formatted(.dateTime.month(.wide).day()))
                            .font(.headline)
                        Image(systemName: "chevron.down")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isDatePickerPresented) {
                    DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding(8)
                }

                Button { moveDay(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                .help("Next day")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isAmoledTheme ? AnyShapeStyle(Color.black) : AnyShapeStyle(.regularMaterial))
    }
    
    // MARK: - Day Grid
    
    private func dayGrid(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Background grid
            VStack(spacing: 0) {
                timeGrid
            }
            
            // Events
            eventViews
            
            // Current time indicator
            if Calendar.current.isDateInToday(selectedDate) {
                currentTimeIndicator(width: width)
            }
        }
        .frame(height: CGFloat(endHour - startHour + 1) * hourHeight)
    }
    
    private var timeGrid: some View {
        ForEach(startHour...endHour, id: \.self) { hour in
            HStack(spacing: 0) {
                Text(formatHour(hour))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.trailing, 12)
                    .offset(y: -10)

                Rectangle()
                    .fill(Color.primary.opacity(appViewModel.gridLineOpacity))
                    .frame(height: appViewModel.gridLineThickness)
            }
            .frame(height: hourHeight, alignment: .top)
        }
    }
    
    private var eventViews: some View {
        ForEach(layouts) { layout in
            DayEventItemView(event: layout.event)
                .frame(width: layout.rect.width, height: layout.rect.height)
                .position(x: layout.rect.origin.x, y: layout.rect.origin.y)
        }
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
                        Text(context.date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2).fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(appViewModel.accentColor))
                            .frame(width: timeColumnWidth - 8, alignment: .trailing)

                        Circle()
                            .fill(appViewModel.accentColor)
                            .frame(width: 7, height: 7)
                            .offset(x: -3)
                    }
                }
                .offset(y: yPos)
            }
        }
    }
    
    // MARK: - Layout Calculation
    
    private func calculateLayout() {
        guard viewWidth > 0 else { return }
        
        let availableWidth = viewWidth - timeColumnWidth - 12
        let dayEvents = eventsForSelectedDay
        
        layouts = WeekViewLayoutEngine.calculateDayLayout(
            for: dayEvents,
            startHour: startHour,
            endHour: endHour,
            width: availableWidth,
            timeColumnWidth: timeColumnWidth + 12,
            hourHeight: hourHeight
        )
    }
    
    // MARK: - Helpers
    
    private func moveDay(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private var eventsForSelectedDay: [Event] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.startTime, inSameDayAs: selectedDate) }
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
    
    private func getYPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        let timeOffset = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
        return timeOffset * hourHeight
    }
}

// MARK: - Day Event Item View

struct DayEventItemView: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var showingDetail = false
    @State private var isHovering = false
    
    private var eventColor: Color {
        appViewModel.getCustomColor(for: event.title) ?? event.color(from: event.title)
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
            HStack(spacing: 8) {
                // Time column
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .fontWeight(.semibold)
                    Text(event.endTime.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                }
                .frame(width: 50)
                
                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    if !event.location.isEmpty {
                        Label(event.location, systemImage: "mappin.circle")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    
                    if let note = appViewModel.getNote(for: event), !note.note.isEmpty {
                        Label("Has note", systemImage: "note.text")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Important reminder star
                Button {
                    toggleImportant()
                } label: {
                    Image(systemName: isImportant ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundColor(isImportant ? .yellow : (isHovering ? .gray.opacity(0.8) : .gray.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .help(isImportant ? "Remove important reminder" : "Mark as important")
                .padding(.trailing, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(eventColor.opacity(0.15))
            .overlay(
                Rectangle()
                    .fill(eventColor)
                    .frame(width: 4),
                alignment: .leading
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(eventColor.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(isHovering ? 0.15 : 0.08), radius: isHovering ? 6 : 3)
            .scaleEffect(isHovering ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $showingDetail) {
            EventDetailPopover(event: event)
        }
    }
}
