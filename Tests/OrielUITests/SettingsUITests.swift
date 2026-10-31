import XCTest

/// Settings opens when the user starts Oriel, its sidebar opens each pane, About names the app, and closing the window
/// leaves Oriel running (PLAN §10.1, checklist item "Closing every window leaves Oriel running"). UI tests use XCTest
/// because they need `XCUIApplication`, and run only with ORIEL_UI_TESTS=1 (Automation Mode).
final class SettingsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testStartingOrielOpensSettings() {
        let app = OrielApp.launch(onboardingCompleted: true)
        defer { app.terminate() }
        XCTAssertTrue(OrielApp.settingsWindow(of: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testTheSidebarOpensEachPane() {
        let app = OrielApp.launch(onboardingCompleted: true)
        defer { app.terminate() }
        let window = OrielApp.settingsWindow(of: app)
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        // The app's own panes, each with something only it shows; the tools' panes sit between General and Shortcuts.
        let panes: [(title: String, shows: XCUIElement)] = [
            ("General", window.checkBoxes["Open Oriel at login"]),
            ("Shortcuts", window.staticTexts["Global shortcuts"]),
            ("Permissions", window.buttons["Check again"]),
            ("Advanced", window.staticTexts["Diagnostics"]),
            ("About", window.buttons["Copy update command"]),
        ]
        for pane in panes {
            let row = OrielApp.sidebarRow(pane.title, in: window)
            XCTAssertTrue(row.waitForExistence(timeout: 5), "\(pane.title) is not in the sidebar")
            row.click()
            XCTAssertTrue(pane.shows.waitForExistence(timeout: 5), "\(pane.title) did not open")
        }
        XCTAssertTrue(OrielApp.sidebarRow("Window Switcher", in: window).exists, "the tools' panes are missing")
    }

    @MainActor
    func testClosingSettingsLeavesOrielRunning() {
        let app = OrielApp.launch(onboardingCompleted: true)
        defer { app.terminate() }
        let window = OrielApp.settingsWindow(of: app)
        XCTAssertTrue(window.waitForExistence(timeout: 10))
        window.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))
        XCTAssertNotEqual(app.state, .notRunning)
    }
}
