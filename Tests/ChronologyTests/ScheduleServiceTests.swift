import XCTest
@testable import Chronology

final class ScheduleServiceTests: XCTestCase {
    private let validICS = """
    BEGIN:VCALENDAR
    BEGIN:VEVENT
    DTSTART:20231027T080000Z
    DTEND:20231027T090000Z
    SUMMARY:Math
    END:VEVENT
    END:VCALENDAR
    """

    private func response(_ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com/a.ics")!, statusCode: status, httpVersion: nil, headerFields: nil)!
    }

    func testWebcalSchemeIsRewrittenToHTTPS() throws {
        let url = try ScheduleService.normalizedURL("webcal://cloud.timeedit.net/x.ics")
        XCTAssertEqual(url.absoluteString, "https://cloud.timeedit.net/x.ics")
    }

    func testURLIsTrimmed() throws {
        let url = try ScheduleService.normalizedURL("  https://example.com/a.ics\n")
        XCTAssertEqual(url.host, "example.com")
    }

    func testInvalidURLThrows() {
        XCTAssertThrowsError(try ScheduleService.normalizedURL("not a url"))
        XCTAssertThrowsError(try ScheduleService.normalizedURL(""))
    }

    func testDecodeParsesCalendar() throws {
        let events = try ScheduleService.decode(data: Data(validICS.utf8), response: response(200))
        XCTAssertEqual(events.map(\.title), ["Math"])
    }

    func testDecodeRejectsHTML() {
        let html = Data("  <!DOCTYPE html><html><body>Login</body></html>".utf8)
        XCTAssertThrowsError(try ScheduleService.decode(data: html, response: response(200))) { error in
            guard case ScheduleService.FetchError.parsingError = error else {
                return XCTFail("Expected parsingError, got \(error)")
            }
        }
    }

    func testDecodeRejectsHTTPErrors() {
        XCTAssertThrowsError(try ScheduleService.decode(data: Data(validICS.utf8), response: response(404))) { error in
            guard case ScheduleService.FetchError.httpStatus(404) = error else {
                return XCTFail("Expected httpStatus(404), got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("not found"))
        }
    }

    func testDecodeRejectsEmptyBody() {
        XCTAssertThrowsError(try ScheduleService.decode(data: Data(), response: response(200)))
    }
}
