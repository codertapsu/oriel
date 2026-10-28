import CoreGraphics
import OrielCore
import Testing
@testable import WindowSwitcher

/// The store builds the list from AX + CGWindowList + SkyLight (PLAN §13.2), here through a fake source.
struct WindowStoreTests {
    private func byID(_ entries: [WindowEntry]) -> [UInt32: WindowEntry] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    @Test func bootstrapMergesTheThreeSourcesAndDropsHelpers() async {
        let (store, _) = await Fixture.store()
        let entries = await store.entries
        // Not: 12 and 13 (menu-bar-sized and hidden helpers on no Space), 15 (palette subrole),
        // 16 (layer 8), 28 (MenuBarAgent has no layer-0 window), 30 (an agent's helper).
        #expect(Set(entries.map(\.id)) == [10, 11, 14, 20, 21, 50])
    }

    @Test func windowsCarryTheirStateAndPlace() async throws {
        let (store, _) = await Fixture.store()
        let windows = await byID(store.entries)
        let current = try #require(windows[10]?.info)
        #expect(current.title == "Apple" && current.isOnCurrentSpace && current.spaceIndex == 1 && current.displayID == 1)
        #expect(current.frame == Fixture.windowFrame)
        let otherSpace = try #require(windows[11])
        #expect(otherSpace.info.title == "GitHub")
        #expect(!otherSpace.info.isOnCurrentSpace && otherSpace.info.spaceIndex == 2 && otherSpace.isActionable)
        let fullScreen = try #require(windows[14]?.info)
        #expect(fullScreen.isFullScreen && fullScreen.spaceIndex == 3 && !fullScreen.isOnCurrentSpace)
        #expect(windows[20]?.info.isHidden == true)
        let minimized = try #require(windows[21]?.info)
        #expect(minimized.isMinimized && minimized.isOnCurrentSpace && minimized.spaceIndex == nil)
    }

    @Test func mruPutsTheFocusedWindowFirstThenTheServerOrder() async {
        let (store, _) = await Fixture.store()
        #expect(await store.entries.map(\.id) == [10, 50, 11, 14, 20, 21])
    }

    @Test func onlyCandidatesForOtherSpacesAreLookedUp() async {
        let (_, source) = await Fixture.store()
        let requests = await source.otherSpaceRequests
        // 12 and 13 are on no Space and 15 and 16 are visible: none of them is worth a remote-token search.
        #expect(requests[Fixture.safari] == [11, 14])
        #expect(requests[Fixture.notes] == nil)
    }

    @Test func accessoryAppsCountOnlyWithARealWindow() async {
        let (_, source) = await Fixture.store()
        let reads = await source.accessibilityReads
        // The agent owns only an off-screen helper on no Space; MenuBarAgent owns no layer-0 window.
        #expect(!reads.contains(Fixture.agent))
        #expect(!reads.contains(Fixture.menuAgent))
        #expect(reads.contains(Fixture.safari))

        let withSettings = await Fixture.source()
        let menuApp = AppRecord(pid: 310, bundleID: "com.example.menu", name: "Menu App", policy: .accessory)
        await withSettings.set(apps: Fixture.apps + [menuApp])
        await withSettings.set(server: Fixture.server + [
            ServerWindowRecord(id: 31, pid: 310, frame: CGRect(x: 0, y: 0, width: 600, height: 400), isOnScreen: true),
        ])
        await withSettings.set(accessibility: .windows([AXWindowRecord(windowID: 31, title: "Settings")]), for: 310)
        let store = WindowStore(source: withSettings)
        await store.bootstrap()
        #expect(await store.entry(for: 31)?.info.title == "Settings")
    }

    @Test func withoutRemoteTokensOtherSpaceWindowsAreListedByAppName() async throws {
        let (store, _) = await Fixture.store(capabilities: SourceCapabilities(canReachOtherSpaces: false))
        let windows = await byID(store.entries)
        let fallback = try #require(windows[11])
        #expect(fallback.info.title == "Safari" && !fallback.isActionable && !fallback.info.isOnCurrentSpace)
        #expect(windows[14]?.info.isFullScreen == true)
        #expect(windows[12] == nil && windows[13] == nil)
    }

    @Test func withoutSkyLightOnlyAccessibilityWindowsAppear() async {
        let (store, _) = await Fixture.store(capabilities: SourceCapabilities(canReadSpaces: false), spaces: nil)
        let entries = await store.entries
        #expect(Set(entries.map(\.id)) == [10, 20, 21, 50])
        #expect(entries.allSatisfy { $0.info.isOnCurrentSpace && $0.info.spaceIndex == nil })
        #expect(entries.first { $0.id == 10 }?.info.displayID == Fixture.display.id)
    }

    @Test func exceptionsCanHideAnAppsWindows() async {
        let rules = EligibilityRules(exceptions: [AppException(bundleID: "com.vmware.fusion", hidesWindows: true, ignoresShortcuts: true)])
        let (store, _) = await Fixture.store(rules: rules)
        #expect(await !store.entries.contains { $0.id == 50 })
        await store.setRules(EligibilityRules())
        #expect(await store.entries.contains { $0.id == 50 })
    }

    @Test func aBurstOfNotificationsRereadsTheAppOnce() async {
        let (store, source) = await Fixture.store()
        await source.resetCounters()
        await source.set(
            accessibility: .windows([AXWindowRecord(windowID: 10, title: "Apple — Renamed", frame: Fixture.windowFrame)]),
            for: Fixture.safari
        )
        await store.process(Array(repeating: .windowsChanged(Fixture.safari), count: 5))
        #expect(await source.accessibilityReads == [Fixture.safari])
        #expect(await store.entry(for: 10)?.info.title == "Apple — Renamed")
    }

    @Test func focusChangesReorderTheList() async {
        let (store, source) = await Fixture.store()
        await source.set(focused: 20, for: Fixture.notes)
        await store.process([.focusedWindowChanged(Fixture.notes)])
        #expect(await store.entries.first?.id == 20)
        await store.noteFocused(14)
        #expect(await store.entries.prefix(2).map(\.id) == [14, 20])
    }

    @Test func terminatedAppsDisappear() async {
        let (store, source) = await Fixture.store()
        await source.set(apps: Fixture.apps.filter { $0.pid != Fixture.safari })
        await source.set(server: Fixture.server.filter { $0.pid != Fixture.safari })
        await store.process([.appTerminated(Fixture.safari)])
        #expect(await Set(store.entries.map(\.id)) == [20, 21, 50])
        #expect(await source.forgotten == [Fixture.safari])
    }

    @Test func anAppThatRefusedIsRetriedOnActivationOnly() async {
        let source = await Fixture.source()
        let late = AppRecord(pid: 600, bundleID: "com.example.late", name: "Late")
        await source.set(apps: Fixture.apps + [late])
        await source.set(accessibility: .refused, for: 600)
        await source.set(server: Fixture.server + [ServerWindowRecord(id: 60, pid: 600, frame: Fixture.windowFrame)])
        var spaces = Fixture.spaces
        spaces.windowSpaces[60] = [1]
        await source.set(spaces: spaces)
        let store = WindowStore(source: source)
        await store.bootstrap()
        #expect(await store.entry(for: 60) == nil)

        await source.set(accessibility: .windows([AXWindowRecord(windowID: 60, title: "Ready")]), for: 600)
        await store.process([.screensChanged])
        #expect(await store.entry(for: 60) == nil)
        await store.process([.appActivated(600)])
        #expect(await store.entry(for: 60)?.info.title == "Ready")
        #expect(await source.accessibilityReads.filter { $0 == 600 }.count == 2)
    }

    @Test func aSpaceChangeRereadsEveryApp() async {
        let (store, source) = await Fixture.store()
        await source.resetCounters()
        var spaces = Fixture.spaces
        spaces.displays[0].currentSpaceID = 2
        await source.set(spaces: spaces)
        // On Space 2, AX lists window 11; window 10 is reached through its cached element.
        await source.set(accessibility: .windows([AXWindowRecord(windowID: 11, title: "GitHub")]), for: Fixture.safari)
        await source.set(reachable: Fixture.reachable + [AXWindowRecord(windowID: 10, title: "Apple")])
        await store.process([.activeSpaceChanged])
        let reads = await Set(source.accessibilityReads)
        #expect(reads.isSuperset(of: [Fixture.safari, Fixture.notes, Fixture.fusion]))
        let now = await byID(store.entries)
        #expect(now[11]?.info.isOnCurrentSpace == true)
        #expect(now[10]?.info.isOnCurrentSpace == false && now[10]?.info.spaceIndex == 1)
    }

    @Test func windowsLostWhileTheScreenWasLockedComeBackOnUnlock() async {
        let (store, source) = await Fixture.store()
        // While locked, AX lists the app element instead of windows (macOS 27.0.1).
        let lockedListing = AXWindowsResult.windows([AXWindowRecord(windowID: nil, title: "Safari", role: "AXApplication", subrole: nil)])
        await source.set(accessibility: lockedListing, for: Fixture.safari)
        await store.process([.windowsChanged(Fixture.safari)])
        #expect(await store.entry(for: 10) == nil)
        await source.set(accessibility: Fixture.accessibility[Fixture.safari] ?? .refused, for: Fixture.safari)
        await store.process([.sessionResumed])
        #expect(await store.entry(for: 10)?.info.title == "Apple")
    }

    @Test func snapshotsFollowChanges() async {
        let (store, source) = await Fixture.store()
        let stream = await store.snapshots()
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next()?.count == 6)
        await source.set(server: Fixture.server.filter { $0.id != 50 })
        await source.set(accessibility: .windows([]), for: Fixture.fusion)
        await store.process([.windowsChanged(Fixture.fusion)])
        #expect(await iterator.next()?.count == 5)
    }

    @Test func runFollowsTheSourcesEventsUntilItStops() async {
        let source = await Fixture.source()
        let store = WindowStore(source: source)
        let task = Task { await store.run() }
        await source.set(focused: 21, for: Fixture.notes)
        source.send(.focusedWindowChanged(Fixture.notes))
        var first: UInt32?
        for await entries in await store.snapshots() where entries.first?.id == 21 {
            first = entries.first?.id
            break
        }
        #expect(first == 21)
        #expect(await source.isStarted)
        await source.stop()
        await task.value
    }
}
