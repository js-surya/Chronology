import XCTest
@testable import Chronology

final class MenuBarCountdownTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func event(startIn startMinutes: Double, endIn endMinutes: Double, allDay: Bool = false) -> Event {
        Event(title: "E", location: "", startTime: now.addingTimeInterval(startMinutes * 60),
              endTime: now.addingTimeInterval(endMinutes * 60), description: nil, isAllDay: allDay)
    }

    func testFormatCountdown() {
        XCTAssertEqual(AppViewModel.formatCountdown(5 * 60), "0:05")
        XCTAssertEqual(AppViewModel.formatCountdown(150 * 60), "2:30")
        XCTAssertEqual(AppViewModel.formatCountdown(23 * 3600 + 59 * 60), "23:59")
        XCTAssertEqual(AppViewModel.formatCountdown(3 * 24 * 3600 + 3600), "3d")
        XCTAssertEqual(AppViewModel.formatCountdown(-30), "0:00")
    }

    func testLabelCountsDownToNextEvent() {
        let label = AppViewModel.menuBarLabel(for: [event(startIn: 300, endIn: 360), event(startIn: 45, endIn: 90)], now: now)
        XCTAssertEqual(label, "0:45")
    }

    func testLabelShowsRemainingTimeDuringEvent() {
        XCTAssertEqual(AppViewModel.menuBarLabel(for: [event(startIn: -10, endIn: 50)], now: now), "0:50")
    }

    func testLabelIgnoresFinishedAndAllDayEvents() {
        let label = AppViewModel.menuBarLabel(for: [event(startIn: -120, endIn: -60), event(startIn: -60, endIn: 1440, allDay: true)], now: now)
        XCTAssertEqual(label, "✓")
    }
}

final class ModelTests: XCTestCase {
    func testCourseHueIsDeterministic() {
        // djb2 over UTF-8 — must not change between launches (String.hashValue does)
        XCTAssertEqual(hueForCourse("Math 101"), hueForCourse("Math 101"))
        XCTAssertEqual(hueForCourse(""), Double(5381 % 360))
        XCTAssertTrue((0..<360).contains(hueForCourse("Physics")))
    }

    func testEventDefaultIdIsDerivedFromContent() {
        let start = Date(timeIntervalSince1970: 1_000)
        let a = Event(title: "X", location: "", startTime: start, endTime: start, description: nil)
        let b = Event(title: "X", location: "", startTime: start, endTime: start, description: nil)
        XCTAssertEqual(a.id, b.id)
    }

    func testProfileDecodesLegacyDataWithoutEmoji() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Old","icalUrl":"https://x"}"#
        let profile = try JSONDecoder().decode(ScheduleProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.name, "Old")
        XCTAssertEqual(profile.emoji, "calendar")
        XCTAssertEqual(profile.description, "")
        XCTAssertNil(profile.emojiColor)
    }

    func testProfileRoundTrips() throws {
        let profile = ScheduleProfile(name: "P", icalUrl: "https://x", description: "d", emoji: "book")
        let decoded = try JSONDecoder().decode(ScheduleProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(decoded, profile)
    }
}
