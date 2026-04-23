import SwiftUI

struct DayView: View {
    let events: [Event]
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @Binding var selectedDate: Date

    @State private var layouts: [EventLayout] = []
    @State private var viewWidth: CGFloat = 0

    @AppStorage("use24HourFormat") private var use24HourFormat = true
    @AppStorage("startHour") private var startHour = 8
    @AppStorage("endHour") private var endHour = 20

    private let hourHeight: CGFloat = 58
    private let timeColumnWidth: CGFloat = 64

    private var theme: AppTheme { appViewModel.resolvedTheme(for: systemColorScheme) }

    private var weekDays: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: selectedDate)
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: selectedDate) else { return [] }
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        VStack(spacing: 0) {
            dayPicker
            Divider()

            GeometryReader { geometry in
                ScrollView {
                    dayGrid(width: geometry.size.width)
                        .padding(.top, 12)
                }
                .onAppear {
                    viewWidth = geometry.size.width
                    calculateLayout()
                }
                .onChange(of: geometry.size.width) { _, w in
                    viewWidth = w
                    calculateLayout()
                }
                .onChange(of: selectedDate) { _, _ in calculateLayout() }
                .onChange(of: events.count) { _, _ in calculateLayout() }
            }
        }
    }

    // MARK: - 7-day picker

    private var dayPicker: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.self) { date in
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                let isToday = Calendar.current.isDateInToday(date)

                Button { selectedDate = date } label: {
                    VStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isSelected ? appViewModel.accentColor : .secondary)
                            .tracking(0.5)

                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 15, weight: isSelected || isToday ? .semibold : .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(isSelected ? .white : (isToday ? appViewModel.accentColor : .primary))
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isSelected ? appViewModel.accentColor : Color.clear)
                                    .shadow(color: isSelected ? appViewModel.accentColor.opacity(0.4) : .clear,
                                            radius: 6, y: 2)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .background(theme.isSolid ? AnyShapeStyle(Color.primary.opacity(0.04)) : AnyShapeStyle(.regularMaterial))
    }

    // MARK: - Day grid

    private func dayGrid(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                timeGrid
            }

            eventViews
            halfHourGuides(width: width)

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
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(width: timeColumnWidth, alignment: .trailing)
                    .padding(.trailing, 10)
                    .offset(y: -8)

                Rectangle()
                    .fill(Color.primary.opacity(appViewModel.gridLineOpacity))
                    .frame(height: appViewModel.gridLineThickness)
            }
            .frame(height: hourHeight, alignment: .top)
        }
    }

    private func halfHourGuides(width: CGFloat) -> some View {
        let count = endHour - startHour
        return Canvas { ctx, size in
            for i in 0..<count {
                let y = CGFloat(i) * hourHeight + hourHeight / 2
                var path = Path()
                path.move(to: CGPoint(x: timeColumnWidth, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(.primary.opacity(0.05)),
                           style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
    }

    private var eventViews: some View {
        ForEach(layouts) { layout in
            EventCardView(event: layout.event, theme: theme, compact: false)
                .frame(width: layout.rect.width, height: layout.rect.height)
                .position(x: layout.rect.origin.x, y: layout.rect.origin.y)
                .environmentObject(appViewModel)
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
                            .fill(Color(hex: "FF3B30"))
                            .frame(height: 1.5)
                    }
                    HStack(spacing: 0) {
                        Spacer().frame(width: timeColumnWidth - 7)
                        ZStack {
                            Circle()
                                .fill(Color(hex: "FF3B30").opacity(0.25))
                                .frame(width: 15, height: 15)
                            Circle()
                                .fill(Color(hex: "FF3B30"))
                                .frame(width: 9, height: 9)
                                .shadow(color: Color(hex: "FF3B30").opacity(0.7), radius: 6)
                        }
                    }
                }
                .offset(y: yPos)
            }
        }
    }

    // MARK: - Layout

    private func calculateLayout() {
        guard viewWidth > 0 else { return }
        let available = viewWidth - timeColumnWidth - 14
        layouts = WeekViewLayoutEngine.calculateDayLayout(
            for: eventsForSelectedDay,
            startHour: startHour,
            endHour: endHour,
            width: available,
            timeColumnWidth: timeColumnWidth + 14,
            hourHeight: hourHeight
        )
    }

    private var eventsForSelectedDay: [Event] {
        events.filter { Calendar.current.isDate($0.startTime, inSameDayAs: selectedDate) }
    }

    private func getYPosition(for date: Date) -> CGFloat {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: date)
        let minute = cal.component(.minute, from: date)
        return CGFloat(hour - startHour) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }

    private func formatHour(_ hour: Int) -> String {
        if use24HourFormat { return String(format: "%02d:00", hour) }
        let period = hour < 12 ? "AM" : "PM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(h) \(period)"
    }
}

// MARK: - Glass day event card

struct GlassDayEventCard: View {
    let event: Event
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @State private var showingDetail = false
    @State private var isHovering = false

    private var eventColor: Color {
        appViewModel.getCustomColor(for: event.title) ?? event.color(from: event.title)
    }

    private var theme: AppTheme { appViewModel.resolvedTheme(for: systemColorScheme) }
    private var isImportant: Bool { appViewModel.isEventImportant(event) }

    var body: some View {
        Button { showingDetail = true } label: {
            ZStack(alignment: .leading) {
                // Glass background
                cardBackground

                // Accent bar
                Capsule()
                    .fill(eventColor)
                    .frame(width: 3)
                    .padding(.vertical, 8)
                    .padding(.leading, 14)
                    .shadow(color: eventColor.opacity(0.8), radius: 4)

                // Content
                HStack(spacing: 0) {
                    Spacer().frame(width: 26)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                        if !event.location.isEmpty {
                            Label(event.location, systemImage: "mappin.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(event.startTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption.bold())
                            .monospacedDigit()
                        Text(event.endTime.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        if isHovering || isImportant {
                            Button {
                                appViewModel.toggleImportant(event)
                            } label: {
                                Image(systemName: isImportant ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(isImportant ? .yellow : .secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 2)
                        }
                    }
                    .padding(.trailing, 14)
                }
                .padding(.vertical, 12)
            }
            .scaleEffect(isHovering ? 1.01 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = h }
        }
        .popover(isPresented: $showingDetail) {
            EventDetailPopover(event: event)
                .environmentObject(appViewModel)
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if theme.isSolid {
            RoundedRectangle(cornerRadius: 10)
                .fill(eventColor.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(eventColor.opacity(0.18))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
    }
}
