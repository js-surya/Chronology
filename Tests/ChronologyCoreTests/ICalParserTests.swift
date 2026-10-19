import XCTest
@testable import ChronologyCore

final class ICalParserTests: XCTestCase {
    private func ics(_ body: String) -> String {
        "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n\(body)\r\nEND:VCALENDAR\r\n"
    }

    private func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testParseBasicEvent() {
        let events = ICalParser.parse(icsContent: ics("""
        BEGIN:VEVENT\r
        UID:abc-1\r
        DTSTART:20231027T080000Z\r
        DTEND:20231027T100000Z\r
        SUMMARY:Math 101\r
        LOCATION:Room 101\r
        DESCRIPTION:Introduction to Algebra\r
        END:VEVENT
        """))

        XCTAssertEqual(events.count, 1)
        let event = events[0]
        XCTAssertEqual(event.title, "Math 101")
        XCTAssertEqual(event.location, "Room 101")
        XCTAssertEqual(event.description, "Introduction to Algebra")
        XCTAssertEqual(event.startTime, utc(2023, 10, 27, 8))
        XCTAssertEqual(event.endTime, utc(2023, 10, 27, 10))
        XCTAssertFalse(event.isAllDay)
    }

    func testUnfoldsContinuationLines() {
        // RFC 5545 §3.1: CRLF followed by a single space/tab continues the previous line
        let events = ICalParser.parse(icsContent: ics("""
        BEGIN:VEVENT\r
        DTSTART:20231027T080000Z\r
        DTEND:20231027T100000Z\r
        SUMMARY:Advanced Distributed Sys\r
         tems Lecture\r
        LOCATION:Building A\r
        \tRoom 4\r
        DESCRIPTION:Line one\\nLine\r
         two\r
        END:VEVENT
        """))

        XCTAssertEqual(events.first?.title, "Advanced Distributed Systems Lecture")
        XCTAssertEqual(events.first?.location, "Building ARoom 4")
        XCTAssertEqual(events.first?.description, "Line one\nLinetwo")
    }

    func testUnescapesText() {
        let events = ICalParser.parse(icsContent: ics(#"""
        BEGIN:VEVENT
        DTSTART:20231027T080000Z
        DTEND:20231027T100000Z
        SUMMARY:Lab\, group A\; B
        LOCATION:C:\\temp
        DESCRIPTION:a\nb\Nc
        END:VEVENT
        """#))

        XCTAssertEqual(events.first?.title, "Lab, group A; B")
        XCTAssertEqual(events.first?.location, #"C:\temp"#)
        XCTAssertEqual(events.first?.description, "a\nb\nc")
    }

    func testHonoursTZID() {
        let events = ICalParser.parse(icsContent: ics("""
        BEGIN:VEVENT
        DTSTART;TZID=Europe/Stockholm:20240115T090000
        DTEND;TZID="Europe/Stockholm":20240115T103000
        SUMMARY:Seminar
        END:VEVENT
        """))

        // Stockholm is UTC+1 in January
        XCTAssertEqual(events.first?.startTime, utc(2024, 1, 15, 8))
        XCTAssertEqual(events.first?.endTime, utc(2024, 1, 15, 9, 30))
    }

    func testFloatingTimeUsesLocalTimeZone() {
        let events = ICalParser.parse(icsContent: ics("""
        BEGIN:VEVENT
        DTSTART:20240115T090000
        DTEND:20240115T100000
        SUMMARY:Floating
        END:VEVENT
        """))

        let comps = Calendar.current.dateComponents([.hour, .minute], from: events[0].startTime)
        XCTAssertEqual(comps.hour, 9)
        XCTAssertEqual(comps.minute, 0)
    }

    func testAllDayEvent() {
        let events = ICalParser.parse(icsContent: ics("""
        BEGIN:VEVENT
        DTSTART;VALUE=DATE:20240301
        SUMMARY:Exam week
        END:VEVENT
        """))

        XCTAssertEqual(events.count, 1)
        let event = events[0]
        XCTAssertTrue(event.isAllDay)
        XCTAssertEqual(Calendar.current.dateComponents([.year, .month, .day, .hour], from: event.startTime),
                       DateComponents(year: 2024, month: 3, day: 1, hour: 0))
        // Missing DTEND on an all-day event lasts one day
        XCTAssertEqual(event.endTime, Calendar.current.date(byAdding: .day, value: 1, to: event.startTime))
    }

    func testMissingDTENDOnTimedEventIsInstant() {
        let events = ICalParser.parse(icsContent: ics("""
        BEGIN:VEVENT
        DTSTART:20231027T080000Z
        SUMMARY:Deadline
        END:VEVENT
        """))
        XCTAssertEqual(events.first?.endTime, events.first?.startTime)
    }

    func testSkipsEventsWithoutStartAndIgnoresOtherComponents() {
        let events = ICalParser.parse(icsContent: ics("""
        BEGIN:VTIMEZONE
        TZID:Europe/Stockholm
        BEGIN:STANDARD
        DTSTART:19701025T030000
        END:STANDARD
        END:VTIMEZONE
        BEGIN:VEVENT
        SUMMARY:No start
        END:VEVENT
        BEGIN:VTODO
        DTSTART:20231027T080000Z
        SUMMARY:Todo
        END:VTODO
        """))
        XCTAssertTrue(events.isEmpty)
    }

    func testQuotedParameterContainingColon() {
        let events = ICalParser.parse(icsContent: ics("""
        BEGIN:VEVENT
        DTSTART:20231027T080000Z
        DTEND:20231027T090000Z
        SUMMARY;ALTREP="http://example.com/a:b":Talk
        END:VEVENT
        """))
        XCTAssertEqual(events.first?.title, "Talk")
    }

    func testIdsAreStableAcrossParsesAndUniquePerOccurrence() {
        let content = ics("""
        BEGIN:VEVENT
        UID:series-1
        DTSTART:20231027T080000Z
        DTEND:20231027T090000Z
        SUMMARY:Weekly
        END:VEVENT
        BEGIN:VEVENT
        UID:series-1
        DTSTART:20231103T080000Z
        DTEND:20231103T090000Z
        SUMMARY:Weekly
        END:VEVENT
        """)

        let first = ICalParser.parse(icsContent: content).map(\.id)
        let second = ICalParser.parse(icsContent: content).map(\.id)
        XCTAssertEqual(first, second)
        XCTAssertEqual(Set(first).count, 2)
    }

    func testHandlesLFOnlyLineEndings() {
        let content = "BEGIN:VCALENDAR\nBEGIN:VEVENT\nDTSTART:20231027T080000Z\nDTEND:20231027T090000Z\nSUMMARY:Unix\nEND:VEVENT\nEND:VCALENDAR\n"
        XCTAssertEqual(ICalParser.parse(icsContent: content).first?.title, "Unix")
    }
}
