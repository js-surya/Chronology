import XCTest
@testable import ChronologyCore

final class LiveActivityTargetTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let hour: TimeInterval = 3600

    private func event(_ title: String, startIn minutes: Double, length: Double = 60, allDay: Bool = false) -> Event {
        let start = now.addingTimeInterval(minutes * 60)
        return Event(title: title, location: "", startTime: start, endTime: start.addingTimeInterval(length * 60), description: nil, isAllDay: allDay)
    }

    func testPrefersClassInProgress() {
        let target = Countdown.liveActivityTarget(in: [event("Next", startIn: 20), event("Now", startIn: -10)], now: now, leadTime: hour)
        XCTAssertEqual(target?.title, "Now")
    }

    func testNextClassWithinLeadTime() {
        XCTAssertEqual(Countdown.liveActivityTarget(in: [event("Soon", startIn: 45)], now: now, leadTime: hour)?.title, "Soon")
    }

    func testNothingWhenNextClassIsFarAway() {
        XCTAssertNil(Countdown.liveActivityTarget(in: [event("Later", startIn: 90)], now: now, leadTime: hour))
    }

    func testIgnoresFinishedAndAllDayEvents() {
        let events = [event("Done", startIn: -120), event("Holiday", startIn: -60, length: 24 * 60, allDay: true)]
        XCTAssertNil(Countdown.liveActivityTarget(in: events, now: now, leadTime: hour))
    }
}
