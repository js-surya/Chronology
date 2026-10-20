import XCTest

/// Walks every main screen and attaches a screenshot of each.
/// Expects a schedule profile to exist (add one in the app, or seed the App Group defaults).
final class ScreenTourUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTourOfMainScreens() {
        let upNext = app.buttons["Up Next"]
        XCTAssertTrue(upNext.waitForExistence(timeout: 10), "Main tabs should appear when a profile exists")
        XCTAssertTrue(app.staticTexts["NEXT UP"].waitForExistence(timeout: 10) || app.staticTexts["NOW"].exists)
        snapshot("1-UpNext")

        app.buttons["Calendar"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Today"].waitForExistence(timeout: 5))
        app.buttons["Day"].firstMatch.tap()
        snapshot("2-Calendar-Day")
        app.buttons["Week"].firstMatch.tap()
        snapshot("2-Calendar-Week")
        app.buttons["Day"].firstMatch.tap()

        // Open the first event block in the timeline
        let block = app.buttons.matching(NSPredicate(format: "label CONTAINS '–'")).firstMatch
        if block.waitForExistence(timeout: 5) {
            block.tap()
            XCTAssertTrue(app.navigationBars["Event"].waitForExistence(timeout: 5))
            snapshot("3-EventDetail")
            app.buttons["Done"].tap()
        }

        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        snapshot("4-Settings")

        app.buttons["Search"].firstMatch.tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Data")
        snapshot("5-Search")
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
