import XCTest
@testable import Chronology

final class ICalParserTests: XCTestCase {
    func testParseEvent() {
        let icsContent = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        DTSTART:20231027T080000Z
        DTEND:20231027T100000Z
        SUMMARY:Math 101
        LOCATION:Room 101
        DESCRIPTION:Introduction to Algebra
        END:VEVENT
        END:VCALENDAR
        """
        
        let events = ICalParser.parse(icsContent: icsContent)
        
        XCTAssertEqual(events.count, 1)
        let event = events.first!
        XCTAssertEqual(event.title, "Math 101")
        XCTAssertEqual(event.location, "Room 101")
        XCTAssertEqual(event.description, "Introduction to Algebra")
        
        // Verify dates (simplified check)
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour], from: event.startTime)
        XCTAssertEqual(startComponents.year, 2023)
        XCTAssertEqual(startComponents.month, 10)
        XCTAssertEqual(startComponents.day, 27)
    }
}
