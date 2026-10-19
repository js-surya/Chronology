import Foundation
import SwiftUI

struct EventLayout: Identifiable {
    let id: String
    let event: Event
    let rect: CGRect
}

class WeekViewLayoutEngine {
    /// Column slot for an event inside its overlap cluster.
    struct Slot: Equatable {
        let column: Int
        let columnCount: Int
    }

    static func calculateLayout(for events: [Event], startHour: Int, endHour: Int, dayWidth: CGFloat, timeColumnWidth: CGFloat, hourHeight: CGFloat) -> [EventLayout] {
        let calendar = Calendar.current
        var layouts: [EventLayout] = []

        // Group timed events by day
        let eventsByDay = Dictionary(grouping: events.filter { !$0.isAllDay }) { event -> Int in
            let weekday = calendar.component(.weekday, from: event.startTime)
            return (weekday + 5) % 7 // Monday = 0
        }

        for (dayIndex, dayEvents) in eventsByDay {
            let slots = assignColumns(dayEvents)

            for event in dayEvents {
                let slot = slots[event.id] ?? Slot(column: 0, columnCount: 1)
                let y = yOffset(for: event.startTime, startHour: startHour, hourHeight: hourHeight)
                let height = CGFloat(event.duration) / 3600.0 * hourHeight

                let width = (dayWidth - 4) / CGFloat(slot.columnCount) - 2
                let columnOffset = (CGFloat(slot.column) - CGFloat(slot.columnCount - 1) / 2.0) * (width + 2)
                let centerX = timeColumnWidth + (CGFloat(dayIndex) * dayWidth) + (dayWidth / 2) + columnOffset
                let centerY = y + (height / 2)

                layouts.append(EventLayout(id: event.id, event: event, rect: CGRect(x: centerX, y: centerY, width: width, height: height)))
            }
        }

        return layouts
    }

    static func calculateDayLayout(for events: [Event], startHour: Int, endHour: Int, width: CGFloat, timeColumnWidth: CGFloat, hourHeight: CGFloat) -> [EventLayout] {
        let timed = events.filter { !$0.isAllDay }
        let slots = assignColumns(timed)

        return timed.map { event in
            let slot = slots[event.id] ?? Slot(column: 0, columnCount: 1)
            let y = yOffset(for: event.startTime, startHour: startHour, hourHeight: hourHeight)
            let height = max(40, CGFloat(event.duration) / 3600.0 * hourHeight)

            let eventWidth = (width - CGFloat(slot.columnCount - 1) * 4) / CGFloat(slot.columnCount)
            let x = timeColumnWidth + (CGFloat(slot.column) * (eventWidth + 4))

            return EventLayout(id: event.id, event: event, rect: CGRect(x: x + eventWidth / 2, y: y + height / 2, width: eventWidth, height: height))
        }
    }

    /// Calendar-style packing: events are split into clusters of transitively overlapping events,
    /// each event takes the first free column in its cluster, and every event in a cluster shares
    /// the cluster's column count so cards line up.
    static func assignColumns(_ events: [Event]) -> [String: Slot] {
        let sorted = events.sorted { ($0.startTime, $0.endTime) < ($1.startTime, $1.endTime) }
        var result: [String: Slot] = [:]

        var cluster: [(event: Event, column: Int)] = []
        var columnEnds: [Date] = []
        var clusterEnd = Date.distantPast

        func flush() {
            for item in cluster {
                result[item.event.id] = Slot(column: item.column, columnCount: columnEnds.count)
            }
            cluster.removeAll()
            columnEnds.removeAll()
        }

        for event in sorted {
            if event.startTime >= clusterEnd { flush() }

            if let free = columnEnds.firstIndex(where: { $0 <= event.startTime }) {
                columnEnds[free] = event.endTime
                cluster.append((event, free))
            } else {
                columnEnds.append(event.endTime)
                cluster.append((event, columnEnds.count - 1))
            }
            clusterEnd = max(clusterEnd, event.endTime)
        }
        flush()

        return result
    }

    private static func yOffset(for date: Date, startHour: Int, hourHeight: CGFloat) -> CGFloat {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return (CGFloat(hour - startHour) + CGFloat(minute) / 60.0) * hourHeight
    }
}
