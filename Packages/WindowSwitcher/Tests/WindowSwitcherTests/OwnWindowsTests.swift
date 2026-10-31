import Testing
@testable import WindowSwitcher

/// Oriel's own process is never asked through Accessibility: macOS would answer inside Oriel, on the AX queue, and
/// AppKit would walk Oriel's views off the main thread (docs/os-quirks.md). Its windows come from AppKit instead.
@MainActor
struct OwnWindowsTests {
    @Test func theAXActorNeverAsksOrielItself() async {
        let ax = AXClient(apis: .shared, relay: nil)
        #expect(await ax.windows(of: AXClient.ownPID) == .refused)
        #expect(await ax.focusedWindowID(of: AXClient.ownPID) == nil)
        #expect(await ax.otherSpaceWindows(of: AXClient.ownPID, ids: [1, 2]).isEmpty)
    }

    /// AppKit answers for Oriel: a list (empty in a test run, which shows no window), never `.refused` from AX.
    @Test func theSourceListsOrielsWindowsFromAppKitAndNeverQuitsIt() async {
        let source = SystemWindowSource(observesChanges: false)
        #expect(await source.accessibilityWindows(of: AXClient.ownPID) == .windows([]))
        #expect(await source.otherSpaceWindows(of: AXClient.ownPID, ids: [1]).isEmpty)
        #expect(await source.quit(pid: AXClient.ownPID) == false)
        await source.stop()
    }
}
