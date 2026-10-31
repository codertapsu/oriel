import AppKit
@testable import Oriel
import Testing

/// Oriel is in the Dock while one of its windows is open, and nothing in its menu bar quits it (PLAN §10.1).
@MainActor
struct DockPresenceTests {
    @Test func anOpenWindowPutsOrielInTheDockAndTheLastOneTakesItOut() {
        #expect(DockPresence.isInDock(hasOpenWindows: true, isHidden: false, isInDockNow: false))
        #expect(!DockPresence.isInDock(hasOpenWindows: false, isHidden: false, isInDockNow: true))
    }

    /// Hidden, Oriel's windows are out of sight but still open: it keeps its icon, from which it comes back.
    @Test func hiddenOrielStaysAsItWas() {
        #expect(DockPresence.isInDock(hasOpenWindows: false, isHidden: true, isInDockNow: true))
        #expect(!DockPresence.isInDock(hasOpenWindows: false, isHidden: true, isInDockNow: false))
    }

    /// `OrielApplication` holds activations back until the Dock icon is in place; the test host is Oriel, started by
    /// its own `main`.
    @Test func orielRunsAsOrielApplication() {
        #expect(NSApp is OrielApplication)
    }

    /// ⌘Q closes the windows, and nothing in the menu bar quits Oriel: only Quit in its menu-bar menu does.
    @Test func theMenuBarHasNoQuit() throws {
        let previous = NSApp.mainMenu
        defer { NSApp.mainMenu = previous }
        MainMenu.install(settings: {}, closeWindows: {})
        let items = (NSApp.mainMenu?.items ?? []).flatMap { $0.submenu?.items ?? [] }
        #expect(!items.contains { $0.action == #selector(NSApplication.terminate(_:)) })
        let commandQ = try #require(items.first { $0.keyEquivalent == "q" && $0.keyEquivalentModifierMask == .command })
        #expect(commandQ.title == "Close All Windows")
    }
}
