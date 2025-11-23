import Foundation
import SwiftUI

struct EventLayout: Identifiable {
    let id: UUID
    let event: Event
    let rect: CGRect
}

class WeekViewLayoutEngine {
    static func calculateLayout(for events: [Event], startHour: Int, endHour: Int, dayWidth: CGFloat, timeColumnWidth: CGFloat, hourHeight: CGFloat) -> [EventLayout] {
        let calendar = Calendar.current
        var layouts: [EventLayout] = []
        
        // Group events by day
        let eventsByDay = Dictionary(grouping: events) { event -> Int in
            let weekday = calendar.component(.weekday, from: event.startTime)
            return (weekday + 5) % 7 // Monday = 0
        }
        
        for (dayIndex, dayEvents) in eventsByDay {
            // Sort events by start time
            let sortedEvents = dayEvents.sorted { $0.startTime < $1.startTime }
            
            // Calculate columns for overlapping events
            var columns: [[Event]] = []
            
            for event in sortedEvents {
                var placed = false
                for i in 0..<columns.count {
                    if let lastEvent = columns[i].last, lastEvent.endTime <= event.startTime {
                        columns[i].append(event)
                        placed = true
                        break
                    }
                }
                if !placed {
                    columns.append([event])
                }
            }
            
            // This simple column packing isn't quite the "overlapping" visual style we want (like iCal).
            // A better approach for iCal style:
            // 1. Find clusters of overlapping events.
            // 2. For each cluster, assign columns.
            
            // Let's stick to the logic we had but optimized:
            // For each event, find all overlapping events in this day.
            
            for event in sortedEvents {
                let overlapping = sortedEvents.filter { other in
                    event.id != other.id && eventsOverlap(event, other)
                }
                
                let allInCluster = (overlapping + [event]).sorted { $0.startTime < $1.startTime }
                
                var columnIndex = 0
                var maxColumns = 1
                
                if !overlapping.isEmpty {
                    if let index = allInCluster.firstIndex(where: { $0.id == event.id }) {
                        columnIndex = index
                    }
                    maxColumns = allInCluster.count
                }
                
                // Calculate Frame
                let hour = calendar.component(.hour, from: event.startTime)
                let minute = calendar.component(.minute, from: event.startTime)
                let timeOffset = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
                let y = timeOffset * hourHeight
                let height = CGFloat(event.duration) / 3600.0 * hourHeight
                
                let width = (dayWidth - 4) / CGFloat(maxColumns) - 2
                let columnOffset = (CGFloat(columnIndex) - CGFloat(maxColumns - 1) / 2.0) * (width + 2)
                let centerX = timeColumnWidth + (CGFloat(dayIndex) * dayWidth) + (dayWidth / 2) + columnOffset
                
                let centerY = y + (height / 2)
                
                layouts.append(EventLayout(id: event.id, event: event, rect: CGRect(x: centerX, y: centerY, width: width, height: height)))
            }
        }
        
        return layouts
    }
    
    static func calculateDayLayout(for events: [Event], startHour: Int, endHour: Int, width: CGFloat, timeColumnWidth: CGFloat, hourHeight: CGFloat) -> [EventLayout] {
        let calendar = Calendar.current
        var layouts: [EventLayout] = []
        
        // Sort events by start time
        let sortedEvents = events.sorted { $0.startTime < $1.startTime }
        
        // Find overlapping groups
        for event in sortedEvents {
            let overlapping = sortedEvents.filter { other in
                event.id != other.id && eventsOverlap(event, other)
            }
            
            let allInCluster = (overlapping + [event]).sorted { $0.startTime < $1.startTime }
            
            var columnIndex = 0
            var maxColumns = 1
            
            if !overlapping.isEmpty {
                if let index = allInCluster.firstIndex(where: { $0.id == event.id }) {
                    columnIndex = index
                }
                maxColumns = allInCluster.count
            }
            
            // Calculate Frame
            let hour = calendar.component(.hour, from: event.startTime)
            let minute = calendar.component(.minute, from: event.startTime)
            let timeOffset = CGFloat(hour - startHour) + CGFloat(minute) / 60.0
            let y = timeOffset * hourHeight
            let height = max(40, CGFloat(event.duration) / 3600.0 * hourHeight)
            
            let eventWidth = (width - CGFloat(maxColumns - 1) * 4) / CGFloat(maxColumns)
            let x = timeColumnWidth + (CGFloat(columnIndex) * (eventWidth + 4))
            
            let centerX = x + (eventWidth / 2)
            let centerY = y + (height / 2)
            
            layouts.append(EventLayout(id: event.id, event: event, rect: CGRect(x: centerX, y: centerY, width: eventWidth, height: height)))
        }
        
        return layouts
    }
    
    static private func eventsOverlap(_ event1: Event, _ event2: Event) -> Bool {
        return event1.startTime < event2.endTime && event2.startTime < event1.endTime
    }
}
