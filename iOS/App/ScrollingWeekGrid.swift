import SwiftUI
import ChronologyCore

/// Week view for narrow screens: one continuous strip of days, three to a screen, scrolling sideways
/// under a fixed time column. `leadingDay` is the first visible day; it follows the scroll and,
/// when changed from outside (Today, arrows), scrolls the strip to it.
struct ScrollingWeekGrid: View {
    @Binding var leadingDay: Date
    @Binding var selectedEvent: Event?
    let onSelectDay: (Date) -> Void
    @Environment(AppStore.self) private var store

    static let visibleDays = 3
    private let hourHeight: CGFloat = 60
    @State private var scrolledDay: Date?
    @State private var offsetX: CGFloat = 0

    /// Every day from two weeks before the first event (or today) to two weeks after the last one.
    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let starts = store.events.map(\.startTime)
        let first = cal.startOfDay(for: min(starts.min() ?? today, today, leadingDay))
        let last = cal.startOfDay(for: max(starts.max() ?? today, today, leadingDay))
        guard let from = cal.date(byAdding: .day, value: -14, to: first),
              let count = cal.dateComponents([.day], from: from, to: last).day else { return [today] }
        return (0...(count + 14)).compactMap { cal.date(byAdding: .day, value: $0, to: from) }
    }

    /// The Day Starts/Ends setting, widened to fit every event, so the grid keeps its height while scrolling.
    private var hours: ClosedRange<Int> {
        let cal = Calendar.current
        let timed = store.events.filter { !$0.isAllDay }
        let first = timed.map { cal.component(.hour, from: $0.startTime) }.min() ?? store.dayStartHour
        let last = timed.map { cal.component(.hour, from: $0.endTime.addingTimeInterval(-1)) + 1 }.max() ?? store.dayEndHour
        return min(store.dayStartHour, first)...max(store.dayEndHour, min(24, last))
    }

    var body: some View {
        GeometryReader { geo in
            let columnWidth = (geo.size.width - TimelineGrid.timeColumn) / CGFloat(Self.visibleDays)
            let days = self.days
            let hours = self.hours
            VStack(spacing: 0) {
                header(days: days, columnWidth: columnWidth, width: geo.size.width - TimelineGrid.timeColumn)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: 0) {
                            timeLabels(hours)
                            ScrollView(.horizontal) {
                                LazyHStack(spacing: 0) {
                                    ForEach(days, id: \.self) { day in
                                        DayColumn(day: day, hours: hours, hourHeight: hourHeight,
                                                  width: columnWidth, selectedEvent: $selectedEvent)
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollIndicators(.hidden)
                            .scrollTargetBehavior(.viewAligned)
                            .scrollPosition(id: $scrolledDay, anchor: .leading)
                            // The date header isn't in this scroll view, so it mirrors the offset
                            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in
                                offsetX = x
                            }
                        }
                        .frame(height: CGFloat(hours.count) * hourHeight + 8, alignment: .top)
                        .padding(.top, 8)
                    }
                    .onAppear { scrollToNow(proxy, hours: hours) }
                }
            }
        }
        .onAppear { scrolledDay = leadingDay }
        .onChange(of: scrolledDay) { _, day in
            if let day, day != leadingDay { leadingDay = day }
        }
        .onChange(of: leadingDay) { _, day in
            if scrolledDay != day { withAnimation(.snappy) { scrolledDay = day } }
        }
    }

    private func header(days: [Date], columnWidth: CGFloat, width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: TimelineGrid.timeColumn, height: 0)
            HStack(spacing: 0) {
                ForEach(days, id: \.self) { day in
                    DayHeaderCell(day: day) { onSelectDay(day) }
                        .frame(width: columnWidth)
                }
            }
            .offset(x: -offsetX)
            // Fixed width: the row of every day is far wider than the screen and must not widen the layout
            .frame(width: width, alignment: .leading)
            .clipped()
        }
        .padding(.vertical, 8)
    }

    private func timeLabels(_ hours: ClosedRange<Int>) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(hours), id: \.self) { hour in
                Text(hourLabel(hour, use24Hour: store.use24HourFormat))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: TimelineGrid.timeColumn - 6, alignment: .trailing)
                    .offset(y: -7)
                    .frame(width: TimelineGrid.timeColumn, height: hourHeight, alignment: .topLeading)
                    .id(hour)
            }
        }
    }

    private func scrollToNow(_ proxy: ScrollViewProxy, hours: ClosedRange<Int>) {
        let hour = max(hours.lowerBound, Calendar.current.component(.hour, from: Date()) - 1)
        proxy.scrollTo(min(hour, hours.upperBound), anchor: .top)
    }
}

// MARK: - Day header

private struct DayHeaderCell: View {
    let day: Date
    let onSelect: () -> Void

    var body: some View {
        let isToday = Calendar.current.isDateInToday(day)
        Button(action: onSelect) {
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
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
    }
}

// MARK: - Day column

private struct DayColumn: View {
    let day: Date
    let hours: ClosedRange<Int>
    let hourHeight: CGFloat
    let width: CGFloat
    @Binding var selectedEvent: Event?
    @Environment(AppStore.self) private var store

    var body: some View {
        let events = store.events.filter { !$0.isAllDay && Calendar.current.isDate($0.startTime, inSameDayAs: day) }
        let slots = WeekViewLayoutEngine.assignColumns(events)
        let height = CGFloat(hours.count) * hourHeight
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(Array(hours), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 0.5)
                        .frame(height: hourHeight, alignment: .top)
                }
            }
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 0.5, height: height)
            ForEach(events) { event in
                let slot = slots[event.id] ?? .init(column: 0, columnCount: 1)
                let blockWidth = width / CGFloat(slot.columnCount)
                let blockHeight = max(24, CGFloat(event.duration / 3600) * hourHeight - 2)
                EventBlock(event: event, height: blockHeight, width: blockWidth)
                    .frame(width: blockWidth - 3, height: blockHeight)
                    .offset(x: CGFloat(slot.column) * blockWidth + 1.5, y: yOffset(event.startTime) + 1)
                    .onTapGesture { selectedEvent = event }
            }
            nowLine
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    @ViewBuilder
    private var nowLine: some View {
        TimelineView(.everyMinute) { context in
            if Calendar.current.isDate(day, inSameDayAs: context.date),
               hours.contains(Calendar.current.component(.hour, from: context.date)) {
                HStack(spacing: 0) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Rectangle().fill(.red).frame(height: 1.5)
                }
                .frame(width: width)
                .offset(y: yOffset(context.date) - 4)
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
}
