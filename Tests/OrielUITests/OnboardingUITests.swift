import XCTest

/// Until onboarding is done, starting Oriel shows it instead of Settings; its button closes it and Oriel keeps running
/// (PLAN §10.1). It never presses Open Privacy & Security or a permission's button, which would leave the app.
final class OnboardingUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingShowsFirstAndItsButtonClosesIt() {
        let app = OrielApp.launch(onboardingCompleted: false)
        defer { app.terminate() }
        let window = app.windows["Welcome to Oriel"]
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        XCTAssertTrue(window.staticTexts["Oriel needs a few permissions"].exists)
        XCTAssertFalse(OrielApp.settingsWindow(of: app).exists)
        let done = window.buttons["Done"]
        let button = done.exists ? done : window.buttons["Continue without"]
        XCTAssertTrue(button.exists)
        button.click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))
        XCTAssertNotEqual(app.state, .notRunning)
    }
}
