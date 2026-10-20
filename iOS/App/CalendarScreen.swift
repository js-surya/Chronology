import SwiftUI
import ChronologyCore

/// One-day timeline on iPhone, seven-day grid when there's room (iPad, landscape).
struct CalendarScreen: View {
    @Binding var selectedEvent: Event?
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var anchor = Calendar.current.startOfDay(for: Date())

    private var showsWeek: Bool { sizeClass == .regular }

    private var weekDays: [Date] {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: anchor)
        let monday = cal.date(byAdding: .day, value: -((weekday + 5) % 7), to: anchor) ?? anchor
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.events.isEmpty {
                    ScheduleStatusView()
                } else {
                    VStack(spacing: 0) {
                        if showsWeek {
                            DayHeaderRow(days: weekDays, selected: anchor, timeColumn: TimelineGrid.timeColumn) { anchor = $0 }
                        } else {
                            WeekStrip(days: weekDays, selected: $anchor)
                        }
                        Divider()
                        TimelineGrid(days: showsWeek ? weekDays : [anchor], selectedEvent: $selectedEvent)
                    }
                }
            }
            .navigationTitle(title)
            // iPadOS 26 hides inline titles under the top tab bar, so the week range needs a large title
            .navigationBarTitleDisplayMode(showsWeek ? .large : .inline)
            .toolbar {
                ProfileSwitcher()
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { step(-1) } label: {
                        Label(showsWeek ? "Previous Week" : "Previous Day", systemImage: "chevron.left")
                    }
                    Button("Today") { anchor = Calendar.current.startOfDay(for: Date()) }
                    Button { step(1) } label: {
                        Label(showsWeek ? "Next Week" : "Next Day", systemImage: "chevron.right")
                    }
                }
            }
            .refreshable { await store.refresh(force: true) }
            // Day strip taps, swipes, Today and the arrows all move the anchor
            .haptic(.selection, trigger: anchor)
        }
    }

    private var title: String {
        if showsWeek {
            let first = weekDays.first ?? anchor, last = weekDays.last ?? anchor
            let sameMonth = Calendar.current.isDate(first, equalTo: last, toGranularity: .month)
            return "\(first.formatted(sameMonth ? .dateTime.day() : .dateTime.day().month(.abbreviated))) – \(last.formatted(.dateTime.day().month(.abbreviated)))"
        }
        return anchor.formatted(.dateTime.month(.wide).year())
    }

    private func step(_ direction: Int) {
        let cal = Calendar.current
        anchor = cal.date(byAdding: .day, value: direction * (showsWeek ? 7 : 1), to: anchor) ?? anchor
    }
}

// MARK: - iPhone week strip

private struct WeekStrip: View {
    let days: [Date]
    @Binding var selected: Date
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selected)
                let isToday = Calendar.current.isDateInToday(day)
                Button {
                    withAnimation(.snappy) { selected = day }
                } label: {
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(isToday ? Color.accentColor : .secondary)
                        Text(day.formatted(.dateTime.day()))
                            .font(.body.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? Color.white : (isToday ? Color.accentColor : .primary))
                            .frame(width: 34, height: 34)
                            .background(isSelected ? Color.accentColor : .clear, in: .circle)
                        // Dot when the day has classes
                        Circle()
                            .fill(hasEvents(day) ? Color.secondary : .clear)
                            .frame(width: 4, height: 4)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            // Swipe the strip to move a week
            let weeks = value.translation.width < 0 ? 1 : -1
            if let d = Calendar.current.date(byAdding: .day, value: 7 * weeks, to: selected) {
                withAnimation(.snappy) { selected = d }
            }
        })
    }

    private func hasEvents(_ day: Date) -> Bool {
        store.events.contains { Calendar.current.isDate($0.startTime, inSameDayAs: day) }
    }
}

// MARK: - iPad day headers

private struct DayHeaderRow: View {
    let days: [Date]
    let selected: Date
    let timeColumn: CGFloat
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Zero height: a bare Color.clear would stretch the row vertically
            Color.clear.frame(width: timeColumn, height: 0)
            ForEach(days, id: \.self) { day in
                let isToday = Calendar.current.isDateInToday(day)
                Button { onSelect(day) } label: {
                    HStack(spacing: 6) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isToday ? Color.accentColor : .secondary)
                        Text(day.formatted(.dateTime.day()))
                            .font(.headline)
                            .foregroundStyle(isToday ? Color.white : .primary)
                            .frame(minWidth: 28, minHeight: 28)
                            .background(isToday ? Color.accentColor : .clear, in: .circle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Timeline grid

struct TimelineGrid: View {
    let days: [Date]
    @Binding var selectedEvent: Event?
    @Environment(AppStore.self) private var store

    static let timeColumn: CGFloat = 52
    private let hourHeight: CGFloat = 60

    /// The Day Starts/Ends setting, widened to fit the visible events.
    private var hours: ClosedRange<Int> {
        let cal = Calendar.current
        let visible = visibleEvents
        let first = visible.map { cal.component(.hour, from: $0.startTime) }.min() ?? store.dayStartHour
        let last = visible.map { cal.component(.hour, from: $0.endTime.addingTimeInterval(-1)) + 1 }.max() ?? store.dayEndHour
        return min(store.dayStartHour, first)...max(store.dayEndHour, min(24, last))
    }

    private var visibleEvents: [Event] {
        store.events.filter { event in
            !event.isAllDay && days.contains { Calendar.current.isDate(event.startTime, inSameDayAs: $0) }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let columnWidth = (geo.size.width - Self.timeColumn) / CGFloat(max(days.count, 1))
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        hourLines
                        daySeparators(columnWidth: columnWidth)
                        eventBlocks(columnWidth: columnWidth)
                        nowLine(columnWidth: columnWidth)
                    }
                    .frame(height: CGFloat(hours.count) * hourHeight + 8)
                    .padding(.top, 8)
                }
                .onAppear { scrollToNow(proxy) }
                .onChange(of: days) { _, _ in scrollToNow(proxy) }
            }
        }
    }

    private func scrollToNow(_ proxy: ScrollViewProxy) {
        let hour = max(hours.lowerBound, Calendar.current.component(.hour, from: Date()) - 1)
        proxy.scrollTo(min(hour, hours.upperBound), anchor: .top)
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(Array(hours), id: \.self) { hour in
                HStack(alignment: .top, spacing: 6) {
                    Text(hourLabel(hour))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: Self.timeColumn - 6, alignment: .trailing)
                        .offset(y: -7)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 0.5)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }

    @ViewBuilder
    private func daySeparators(columnWidth: CGFloat) -> some View {
        if days.count > 1 {
            ForEach(0..<days.count, id: \.self) { index in
                Rectangle()
                    .fill(Color.secondary.opacity(0.18))
                    .frame(width: 0.5, height: CGFloat(hours.count) * hourHeight)
                    .offset(x: Self.timeColumn + CGFloat(index) * columnWidth)
            }
        }
    }

    private func eventBlocks(columnWidth: CGFloat) -> some View {
        ForEach(Array(days.enumerated()), id: \.offset) { index, day in
            let dayEvents = visibleEvents.filter { Calendar.current.isDate($0.startTime, inSameDayAs: day) }
            let slots = WeekViewLayoutEngine.assignColumns(dayEvents)
            ForEach(dayEvents) { event in
                let slot = slots[event.id] ?? .init(column: 0, columnCount: 1)
                let width = columnWidth / CGFloat(slot.columnCount)
                let height = max(24, CGFloat(event.duration / 3600) * hourHeight - 2)
                EventBlock(event: event, height: height, narrow: width < 70)
                    .frame(width: width - 3, height: height)
                    .offset(x: Self.timeColumn + CGFloat(index) * columnWidth + CGFloat(slot.column) * width + 1.5,
                            y: yOffset(event.startTime) + 1)
                    .onTapGesture { selectedEvent = event }
            }
        }
    }

    @ViewBuilder
    private func nowLine(columnWidth: CGFloat) -> some View {
        TimelineView(.everyMinute) { context in
            if let index = days.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: context.date) }),
               hours.contains(Calendar.current.component(.hour, from: context.date)) {
                HStack(spacing: 0) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Rectangle().fill(.red).frame(height: 1.5)
                }
                .frame(width: columnWidth + 4)
                .offset(x: Self.timeColumn + CGFloat(index) * columnWidth - 4, y: yOffset(context.date) - 4)
                .allowsHitTesting(false)
            }
        }
    }

    private func yOffset(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        let hour = CGFloat(cal.component(.hour, from: date) - hours.lowerBound)
        let minute = CGFloat(cal.component(.minute, from: date)) / 60
        return (hour + minute) * hourHeight
    }

    private func hourLabel(_ hour: Int) -> String {
        ChronologyMobile.hourLabel(hour, use24Hour: store.use24HourFormat)
    }
}

// MARK: - Event block

struct EventBlock: View {
    let event: Event
    let height: CGFloat
    var narrow = false
    @Environment(AppStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = store.color(for: event)
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        HStack(alignment: .top, spacing: 5) {
            Capsule().fill(color).frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(narrow ? 1 : (height > 60 ? 3 : 1))
                if height > 44 {
                    Text(store.time(event.startTime) + (event.location.isEmpty || narrow ? "" : " · \(event.location)"))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .padding(.leading, 3)
        .padding(.trailing, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            // Opaque base keeps hour lines from showing through the tint
            shape.fill(Color(.systemBackground))
            // A light tint disappears on black, so dark mode needs a stronger one
            shape.fill(color.opacity(colorScheme == .dark ? 0.4 : 0.22))
        }
        .overlay(shape.strokeBorder(color.opacity(colorScheme == .dark ? 0.6 : 0.4), lineWidth: 0.5))
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), \(store.timeRange(event))\(event.location.isEmpty ? "" : ", \(event.location)")")
        .accessibilityAddTraits(.isButton)
    }
}
