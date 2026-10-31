import XCTest

/// Launches the Debug build for a UI test (PLAN §14.3). Settings are JSON in UserDefaults, so a launch argument sets one
/// for that launch only, as property-list data: `<74727565>` is `true`, `<66616c7365>` is `false`.
@MainActor
enum OrielApp {
    static func launch(onboardingCompleted: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-app.onboardingCompleted", onboardingCompleted ? "<74727565>" : "<66616c7365>"]
        app.launch()
        return app
    }

    /// The app under test, next to the test runner in the build products (`OrielUITests-Runner.app` holds this bundle
    /// in `Contents/PlugIns`).
    static var bundleURL: URL {
        var url = Bundle(for: SettingsUITests.self).bundleURL
        for _ in 0 ..< 4 {
            url.deleteLastPathComponent()
        }
        return url.appending(path: "Oriel.app")
    }

    /// The Settings window, found by its sidebar: its title follows the pane shown ("General" when it opens).
    static func settingsWindow(of app: XCUIApplication) -> XCUIElement {
        app.windows.containing(NSPredicate(format: "label == %@", "Permissions")).firstMatch
    }

    /// The sidebar row of a Settings pane.
    static func sidebarRow(_ title: String, in window: XCUIElement) -> XCUIElement {
        let outline = window.outlines.firstMatch
        return (outline.exists ? outline : window.tables.firstMatch).staticTexts[title]
    }
}
