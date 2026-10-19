import XCTest
@testable import ChronologyCore

final class LayoutEngineTests: XCTestCase {
    /// Monday 2024-01-15 in the local time zone.
    private let monday = Calendar.current.date(from: DateComponents(year: 2024, month: 1, day: 15))!

    private func event(_ id: String, _ startHour: Double, _ endHour: Double, dayOffset: Int = 0, allDay: Bool = false) -> Event {
        let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: monday)!
        return Event(
            id: id,
            title: id,
            location: "",
            startTime: day.addingTimeInterval(startHour * 3600),
            endTime: day.addingTimeInterval(endHour * 3600),
            description: nil,
            isAllDay: allDay
        )
    }

    func testNonOverlappingEventsUseSingleColumn() {
        let slots = WeekViewLayoutEngine.assignColumns([event("a", 8, 9), event("b", 10, 11)])
        XCTAssertEqual(slots["a"], .init(column: 0, columnCount: 1))
        XCTAssertEqual(slots["b"], .init(column: 0, columnCount: 1))
    }

    func testBackToBackEventsDoNotOverlap() {
        let slots = WeekViewLayoutEngine.assignColumns([event("a", 8, 9), event("b", 9, 10)])
        XCTAssertEqual(slots["a"]?.columnCount, 1)
        XCTAssertEqual(slots["b"]?.columnCount, 1)
    }

    func testOverlappingPairSplitsInTwo() {
        let slots = WeekViewLayoutEngine.assignColumns([event("a", 8, 10), event("b", 9, 11)])
        XCTAssertEqual(slots["a"], .init(column: 0, columnCount: 2))
        XCTAssertEqual(slots["b"], .init(column: 1, columnCount: 2))
    }

    func testChainReusesFreedColumn() {
        // a overlaps b, b overlaps c, a and c don't: two columns are enough and c reuses a's column
        let slots = WeekViewLayoutEngine.assignColumns([event("a", 8, 10), event("b", 9, 12), event("c", 10, 11)])
        XCTAssertEqual(slots["a"], .init(column: 0, columnCount: 2))
        XCTAssertEqual(slots["b"], .init(column: 1, columnCount: 2))
        XCTAssertEqual(slots["c"], .init(column: 0, columnCount: 2))
    }

    func testSeparateClustersAreIndependent() {
        let slots = WeekViewLayoutEngine.assignColumns([
            event("a", 8, 10), event("b", 8, 10), event("c", 8, 10),
            event("d", 13, 14)
        ])
        XCTAssertEqual(slots["c"], .init(column: 2, columnCount: 3))
        XCTAssertEqual(slots["d"], .init(column: 0, columnCount: 1))
    }

    func testWeekLayoutPlacesEventsInDayColumnsAndSkipsAllDay() {
        let layouts = WeekViewLayoutEngine.calculateLayout(
            for: [event("mon", 8, 9), event("wed", 9, 11, dayOffset: 2), event("holiday", 0, 24, allDay: true)],
            startHour: 8, endHour: 20, dayWidth: 100, timeColumnWidth: 60, hourHeight: 50
        )
        XCTAssertEqual(Set(layouts.map(\.id)), ["mon", "wed"])

        // rect.origin holds the card's centre (views position with .position(x:y:))
        let mon = layouts.first { $0.id == "mon" }!.rect
        XCTAssertEqual(mon.origin.x, 60 + 50)  // timeColumn + half a day
        XCTAssertEqual(mon.origin.y, 25)       // 8:00 at top, one hour tall
        XCTAssertEqual(mon.height, 50)

        let wed = layouts.first { $0.id == "wed" }!.rect
        XCTAssertEqual(wed.origin.x, 60 + 2 * 100 + 50)
        XCTAssertEqual(wed.origin.y, 50 + 50)      // starts one hour down, two hours tall
    }

    func testDayLayoutEnforcesMinimumHeightAndSplitsWidth() {
        let layouts = WeekViewLayoutEngine.calculateDayLayout(
            for: [event("short", 8, 8.25), event("a", 10, 12), event("b", 11, 12)],
            startHour: 8, endHour: 20, width: 404, timeColumnWidth: 60, hourHeight: 60
        )
        let byId = Dictionary(uniqueKeysWithValues: layouts.map { ($0.id, $0.rect) })
        XCTAssertEqual(byId["short"]?.height, 40)
        XCTAssertEqual(byId["a"]?.width, 200)
        XCTAssertEqual(byId["b"]?.width, 200)
        XCTAssertEqual(byId["b"]?.origin.x, 60 + 204 + 100)
    }
}
