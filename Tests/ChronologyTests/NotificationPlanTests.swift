import XCTest
@testable import Chronology

final class NotificationPlanTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func event(_ title: String, inMinutes minutes: Double, location: String = "Room 1", allDay: Bool = false) -> Event {
        let start = now.addingTimeInterval(minutes * 60)
        return Event(title: title, location: location, startTime: start, endTime: start.addingTimeInterval(3600), description: nil, isAllDay: allDay)
    }

    func testSchedulesReminderBeforeFutureEvents() {
        let e = event("Math", inMinutes: 60)
        let plan = NotificationManager.plan(events: [e], minutesBefore: 15, importantEvents: [], now: now)

        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].fireDate, e.startTime.addingTimeInterval(-15 * 60))
        XCTAssertEqual(plan[0].title, "Math starting in 15 min")
        XCTAssertEqual(plan[0].body, "Head to Room 1")
    }

    func testSkipsRemindersWhoseFireDateHasPassed() {
        let plan = NotificationManager.plan(
            events: [event("Soon", inMinutes: 10), event("Past", inMinutes: -30)],
            minutesBefore: 15, importantEvents: [], now: now
        )
        XCTAssertTrue(plan.isEmpty)
    }

    func testSkipsAllDayEvents() {
        let plan = NotificationManager.plan(events: [event("Holiday", inMinutes: 600, allDay: true)], minutesBefore: 15, importantEvents: [], now: now)
        XCTAssertTrue(plan.isEmpty)
    }

    func testIdsAreStableSoReschedulingReplacesInsteadOfDuplicating() {
        let events = [event("A", inMinutes: 60), event("B", inMinutes: 120)]
        let first = NotificationManager.plan(events: events, minutesBefore: 15, importantEvents: [], now: now)
        let second = NotificationManager.plan(events: events, minutesBefore: 15, importantEvents: [], now: now)
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(Set(first.map(\.id)).count, 2)
    }

    func testImportantEventGetsItsOwnReminder() {
        let e = event("Exam", inMinutes: 120)
        let important = ImportantEvent(eventTitle: "Exam", eventDate: e.startTime, reminderMinutes: 60)
        let plan = NotificationManager.plan(events: [e], minutesBefore: 15, importantEvents: [important], now: now)

        XCTAssertEqual(plan.count, 2)
        let reminder = plan.first { $0.id.hasPrefix("important.") }
        XCTAssertEqual(reminder?.fireDate, e.startTime.addingTimeInterval(-60 * 60))
        XCTAssertEqual(reminder?.title, "Important: Exam")
    }

    func testImportantEventOnlyMatchesSameOccurrence() {
        let monday = event("Lecture", inMinutes: 120)
        let nextWeek = event("Lecture", inMinutes: 120 + 7 * 24 * 60)
        let important = ImportantEvent(eventTitle: "Lecture", eventDate: nextWeek.startTime, reminderMinutes: 30)
        let plan = NotificationManager.plan(events: [monday, nextWeek], minutesBefore: 15, importantEvents: [important], now: now)

        let reminders = plan.filter { $0.id.hasPrefix("important.") }
        XCTAssertEqual(reminders.map(\.id), ["important.\(nextWeek.id)"])
    }

    func testResultIsSortedAndCappedToSystemLimit() {
        let events = (1...100).reversed().map { event("E\($0)", inMinutes: Double($0) * 60) }
        let plan = NotificationManager.plan(events: events, minutesBefore: 15, importantEvents: [], now: now)

        XCTAssertEqual(plan.count, NotificationManager.maxPending)
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
        XCTAssertEqual(plan.first?.title, "E1 starting in 15 min")
    }

    func testBodyFallsBackToStartTimeWithoutLocation() {
        let plan = NotificationManager.plan(events: [event("Call", inMinutes: 60, location: "")], minutesBefore: 15, importantEvents: [], now: now)
        XCTAssertTrue(plan[0].body.hasPrefix("Starts at "))
    }
}
