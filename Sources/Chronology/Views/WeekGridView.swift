import SwiftUI

struct WeekGridView: View {
    let events: [Event]
    @EnvironmentObject var appViewModel: AppViewModel
    @Environment(\.colorScheme) var systemColorScheme
    @Binding var currentWeekStart: Date

    @State private var layouts: [EventLayout] = []
    @State private var viewWidth: CGFloat = 0

    @AppStorage("use24HourFormat") private var use24HourFormat = true
    @AppStorage("startHour") private var startHour = 8
    @AppStorage("endHour") private var endHour = 20

    private let hourHeight: CGFloat = 58
    private let timeColumnWidth: CGFloat = 64

    private var theme: AppTheme { appViewModel.resolvedTheme(for: systemColorScheme) }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                calendarGrid(width: geometry.size.width)
            }
            .onAppear {
                viewWidth = geometry.size.width
                calculateLayout()
            }
            .onChange(of: geometry.size.width) { _, w in
                viewWidth = w
                calculateLayout()
            }
            .onChange(of: currentWeekStart) { _, _ in calculateLayout() }
            .onChange(of: events.count) { _, _ in calculateLayout() }
        }
    }

    // MARK: - Calendar Grid

    private func calendarGrid(width: CGFloat) -> some View {
        let dayWidth = (width - timeColumnWidth) / 7
        let totalHeight = CGFloat(endHour - startHour + 1) * hourHeight + 44

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                dayHeaders(dayWidth: dayWidth)
                timeGrid
            }

            daySeparators(dayWidth: dayWidth)
            halfHourGuides(width: width)
            eventViews(dayWidth: dayWidth)

            if isCurrentWeek {
                currentTimeIndicator(width: width)
            }
        }
        .frame(height: totalHeight)
    }

    private func dayHeaders(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth)

            ForEach(0..<7) { dayOffset in
                if let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: currentWeekStart) {
                    let isToday = Calendar.current.isDateInToday(date)
                    VStack(spacing: 3) {
                        Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(isToday ? appViewModel.accentColor : .secondary)
                            .tracking(0.6)

                        Text(date.formatted(.dateTime.day()))
                            .font(.system(size: 15, weight: isToday ? .semibold : .medium, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(isToday ? .white : .primary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(isToday ? appViewModel.accentColor : Color.clear)
                                    .shadow(color: isToday ? appViewModel.accentColor.opacity(0.4) : .clear,
                                            radius: 6, y: 2)
                            )
                    }
                    .frame(width: dayWidth)
                    .padding(.vertical, 4)
                }
            }
        }
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

    private func halfHourGuides(width: CGFloat) -> some View {
        let count = endHour - startHour
        return Canvas { ctx, size in
            for i in 0..<count {
                let y = CGFloat(i) * hourHeight + hourHeight / 2 + 44
                var path = Path()
                path.move(to: CGPoint(x: timeColumnWidth, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(.primary.opacity(0.05)),
                           style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
    }

    private func daySeparators(dayWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: timeColumnWidth)
            ForEach(0..<7) { _ in
                Rectangle()
                    .fill(Color.primary.opacity(appViewModel.gridLineOpacity))
                    .frame(width: appViewModel.gridLineThickness)
                    .frame(width: dayWidth, alignment: .leading)
            }
        }
        .offset(y: 44)
    }

    private func eventViews(dayWidth: CGFloat) -> some View {
        ForEach(layouts) { layout in
            EventCardView(event: layout.event, theme: theme, compact: true)
                .frame(width: layout.rect.width, height: layout.rect.height)
                .position(x: layout.rect.origin.x, y: layout.rect.origin.y + 44)
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
                .offset(y: yPos + 44)
            }
        }
    }

    // MARK: - Layout

    private func calculateLayout() {
        guard viewWidth > 0 else { return }
        let dayWidth = (viewWidth - timeColumnWidth) / 7
        layouts = WeekViewLayoutEngine.calculateLayout(
            for: eventsInCurrentWeek,
            startHour: startHour,
            endHour: endHour,
            dayWidth: dayWidth,
            timeColumnWidth: timeColumnWidth,
            hourHeight: hourHeight
        )
    }

    // MARK: - Helpers

    private var eventsInCurrentWeek: [Event] {
        let cal = Calendar.current
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: currentWeekStart)!
        return events.filter { $0.startTime >= currentWeekStart && $0.startTime < endOfWeek }
    }

    private var isCurrentWeek: Bool {
        let cal = Calendar.current
        let now = Date()
        let endOfWeek = cal.date(byAdding: .day, value: 7, to: currentWeekStart)!
        return now >= currentWeekStart && now < endOfWeek
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

// MARK: - Glass event card

struct GlassEventCard: View {
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
            cardContent
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

    private var cardContent: some View {
        ZStack(alignment: .topLeading) {
            // Background
            cardBackground

            // Left accent bar
            Capsule()
                .fill(eventColor)
                .frame(width: 2.5)
                .padding(.vertical, 5)
                .padding(.leading, 3)
                .shadow(color: eventColor.opacity(0.8), radius: 4)

            // Content
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                    if isHovering || isImportant {
                        Button {
                            appViewModel.toggleImportant(event)
                        } label: {
                            Image(systemName: isImportant ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(isImportant ? .yellow : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !event.location.isEmpty {
                    Text(event.location)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 13)
            .padding(.vertical, 6)
            .padding(.trailing, 8)

            // Important badge
            if isImportant && !isHovering {
                Image(systemName: "star.fill")
                    .font(.system(size: 7))
                    .foregroundColor(.yellow)
                    .padding(3)
                    .background(Circle().fill(Color.black.opacity(0.25)))
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if theme.isSolid {
            RoundedRectangle(cornerRadius: 10)
                .fill(eventColor.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(eventColor.opacity(0.22))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
    }
}
