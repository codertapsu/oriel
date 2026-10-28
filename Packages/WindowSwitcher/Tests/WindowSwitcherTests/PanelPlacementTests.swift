import CoreGraphics
import OrielCore
import Testing
@testable import WindowSwitcher

/// Which display the switcher opens on (PLAN §7.1.3).
struct PanelPlacementTests {
    @Test(arguments: [
        (PanelPlacement.pointer, CGDirectDisplayID(2)),
        (.activeWindow, 3),
        (.mainDisplay, 1),
    ])
    func eachPlacementNamesItsDisplay(_ placement: PanelPlacement, _ expected: CGDirectDisplayID) {
        #expect(placement.display(pointer: 2, activeWindow: 3, main: 1) == expected)
    }

    @Test func anUnknownDisplayFallsBackToThePointersThenTheMainOne() {
        #expect(PanelPlacement.activeWindow.display(pointer: 2, activeWindow: nil, main: 1) == 2)
        #expect(PanelPlacement.mainDisplay.display(pointer: 2, activeWindow: 3, main: nil) == 2)
        #expect(PanelPlacement.activeWindow.display(pointer: nil, activeWindow: nil, main: 1) == 1)
        #expect(PanelPlacement.pointer.display(pointer: nil, activeWindow: nil, main: nil) == nil)
    }

    /// The active app's front window on the current Space decides; minimized, hidden and other-Space windows don't.
    @Test func theActiveWindowIsTheActiveAppsFrontVisibleWindow() {
        let entries = [
            Fixture.entry(1, pid: 10, app: "Safari", display: 1),
            Fixture.entry(2, pid: 20, app: "Notes", minimized: true, display: 1),
            Fixture.entry(3, pid: 20, app: "Notes", currentSpace: false, space: 2, display: 1),
            Fixture.entry(4, pid: 20, app: "Notes", display: 2),
            Fixture.entry(5, pid: 20, app: "Notes", display: 1),
        ]
        let displays = [FilterTests.main, FilterTests.left]
        #expect(PanelPlacement.activeWindowDisplay(in: entries, context: FilterContext(activePID: 20, displays: displays)) == 2)
        #expect(PanelPlacement.activeWindowDisplay(in: entries, context: FilterContext(activePID: 10, displays: displays)) == 1)
        #expect(PanelPlacement.activeWindowDisplay(in: entries, context: FilterContext(activePID: 99, displays: displays)) == nil)
        #expect(PanelPlacement.activeWindowDisplay(in: entries, context: FilterContext(activePID: nil, displays: displays)) == nil)
    }

    @Test func thePanelOpensUnderThePointerUntilToldOtherwise() {
        #expect(SwitcherSettingKeys.placement.defaultValue == .pointer)
        #expect(SwitcherConfiguration().placement == .pointer)
    }
}
