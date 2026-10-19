import XCTest
@testable import ChronologyCore

final class AboutTextTests: XCTestCase {
    func testNameAndTagline() {
        XCTAssertEqual(AboutText.appName, "Chronology")
        XCTAssertFalse(AboutText.tagline.isEmpty)
    }

    func testCreditsAndSourceLink() {
        XCTAssertEqual(AboutText.credit, "Built with ❤️ by SyntaxError and Claude")
        XCTAssertEqual(AboutText.sourceCode.absoluteString, "https://github.com/js-surya/Chronology", "links to the project, not a profile")
    }

    func testDisplayedVersionHasNoBuildNumber() {
        XCTAssertFalse(AboutText.displayVersion.contains("("), AboutText.displayVersion)
        XCTAssertTrue(AboutText.versionWithBuild.hasPrefix(AboutText.displayVersion + " ("), AboutText.versionWithBuild)
    }

    func testAcknowledgementsNameTimeEditTrademark() {
        XCTAssertTrue(AboutText.acknowledgements.contains { $0.contains("TimeEdit") && $0.contains("not affiliated") })
    }

    func testTimelineCountdownPhrase() {
        // Widget and app share this wording; minute precision, no rounding to the hour
        let now = Date(timeIntervalSince1970: 0)
        let event = Event(title: "E", location: "", startTime: now.addingTimeInterval(89 * 60 + 30), endTime: now.addingTimeInterval(3 * 3600), description: nil)
        XCTAssertEqual(Countdown.phrase(for: event, now: now), "In 1h 29m")
        XCTAssertEqual(Countdown.phrase(for: event, now: now.addingTimeInterval(2 * 3600)), "Ends in 1h")
    }
}
