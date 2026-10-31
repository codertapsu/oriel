import ApplicationServices
import CoreGraphics
import Foundation
import OrielCore
import Testing
@testable import WindowSwitcher

/// The Dock's previews and window counts (PLAN §7.1.12): reading the Dock's items, which windows each icon stands for,
/// where counts and the preview go, and when the preview shows and goes. All pure; nothing here touches the Dock.
struct DockTests {
    private static let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")
    private static let code = URL(fileURLWithPath: "/Applications/Visual Studio Code.app")

    /// The dev Mac's Dock on macOS 27.0.1: on the left of a 1920 × 1080 display left of the main one, 35-point icons.
    private static let leftDisplay = CGRect(x: -1920, y: -98, width: 1920, height: 1080)

    private static func item(_ url: URL?, y: CGFloat = 522, kind: DockItem.Kind = .application, title: String = "App") -> DockItem {
        DockItem(kind: kind, title: title, url: url, frame: CGRect(x: -1915, y: y, width: 49, height: 37), isRunning: true)
    }

    private static func window(_ id: UInt32, pid: Int32, bundleID: String?) -> WindowEntry {
        WindowEntry(info: WindowInfo(id: id, pid: pid, appName: "App", bundleID: bundleID, title: "Window \(id)", frame: .zero))
    }

    // MARK: Reading the Dock

    @Test func itemsComeFromTheirAttributes() throws {
        let app = try #require(DockItem.make(
            subrole: kAXApplicationDockItemSubrole, title: "Google Chrome", url: Self.chrome,
            position: CGPoint(x: -1915, y: 522), size: CGSize(width: 49, height: 37), isRunning: true
        ))
        #expect(app.kind == .application && app.isRunning && app.frame == CGRect(x: -1915, y: 522, width: 49, height: 37))
        let trash = try #require(DockItem.make(
            subrole: "AXTrashDockItem", title: "Trash", url: nil, position: .zero, size: CGSize(width: 49, height: 37), isRunning: nil
        ))
        #expect(trash.kind == .other && !trash.isRunning)
        #expect(DockItem
            .make(subrole: kAXApplicationDockItemSubrole, title: "X", url: nil, position: nil, size: nil, isRunning: true) == nil)
    }

    @Test func aStoppedReaderNeverObservesAgain() async {
        let dock = DockAccessibility()
        await dock.stop()
        // A reconnect that arrives after the features stopped: it returns before asking the Dock anything, so no
        // observer is left on the main run loop.
        #expect(await !dock.start(pid: .max))
        #expect(await dock.pid == nil)
    }

    @Test func notificationsSayWhatToReadAgain() {
        #expect(DockNotificationRelay.event(for: kAXSelectedChildrenChangedNotification) == .hoverChanged)
        #expect(DockNotificationRelay.event(for: kAXCreatedNotification) == .itemsChanged)
        #expect(DockNotificationRelay.event(for: kAXUIElementDestroyedNotification) == .itemsChanged)
        #expect(DockNotificationRelay.event(for: kAXFocusedUIElementChangedNotification) == nil)
    }

    @Test func theEdgeFollowsTheListAndItsDisplay() {
        let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let displays = [main, Self.leftDisplay]
        #expect(DockLayout.edge(isVertical: true, frame: CGRect(x: -1910, y: -35, width: 49, height: 985), displays: displays) == .left)
        #expect(DockLayout.edge(isVertical: true, frame: CGRect(x: 1463, y: 100, width: 49, height: 700), displays: displays) == .right)
        #expect(DockLayout.edge(isVertical: false, frame: CGRect(x: 300, y: 920, width: 900, height: 60), displays: displays) == .bottom)
        // An icon read on its own, before the list was.
        #expect(DockLayout.edge(nearest: Self.item(Self.chrome).frame, on: Self.leftDisplay) == .left)
        #expect(DockLayout.edge(nearest: CGRect(x: 700, y: 930, width: 64, height: 52), on: main) == .bottom)
        #expect(DockLayout.edge(nearest: CGRect(x: 1460, y: 400, width: 49, height: 37), on: main) == .right)
    }

    @Test func aHoveredIconIsFoundAmongTheItemsRead() {
        let layout = DockLayout(
            items: [Self.item(Self.code, y: 100), Self.item(Self.chrome, y: 140), Self.item(Self.chrome, y: 180)],
            frame: .zero, edge: .left
        )
        #expect(layout.index(of: Self.item(Self.chrome, y: 181)) == 2)
        #expect(layout.index(of: Self.item(Self.chrome, y: 600)) == 1)
        #expect(layout.index(of: Self.item(nil, y: 100)) == nil)
    }

    // MARK: Reading the icons again

    @Test @MainActor func aShortDelayNeverCutsTheSettleShort() {
        var schedule = DockLayoutSchedule()
        let now = ContinuousClock.now
        // A minimized window's tile leaves the Dock: its icons settle for 0.7 s.
        let settle = schedule.schedule(after: DockController.settleDelay, now: now)
        // The pointer leaves the Dock 50 ms later: its 0.4 s read waits for the settle's.
        #expect(schedule.schedule(after: DockController.leaveDelay, now: now + .milliseconds(50)) == settle)
        // Another settle moves it later.
        #expect(schedule.schedule(after: DockController.settleDelay, now: now + .milliseconds(100)) == now + .milliseconds(800))
    }

    @Test @MainActor func aReadUnderWayWhenAnotherIsAskedForIsNotStored() {
        var schedule = DockLayoutSchedule()
        let now = ContinuousClock.now
        _ = schedule.schedule(after: DockController.leaveDelay, now: now)
        let read = schedule.begin()
        #expect(schedule.due == nil && schedule.isCurrent(read))
        // An icon leaves the Dock while it runs: the settle's read is the one stored, after its own delay.
        let settle = schedule.schedule(after: DockController.settleDelay, now: now + .milliseconds(420))
        #expect(!schedule.isCurrent(read) && settle == now + .milliseconds(1120))
        let next = schedule.begin()
        #expect(schedule.isCurrent(next))
    }

    // MARK: Windows per icon

    @Test func anIconStandsForEveryWindowOfItsApp() {
        let items = [Self.item(Self.chrome), Self.item(Self.code, y: 560), Self.item(nil, y: 600, kind: .other)]
        let entries = [
            Self.window(3, pid: 10, bundleID: "com.google.Chrome"), Self.window(1, pid: 20, bundleID: "com.microsoft.VSCode"),
            Self.window(2, pid: 10, bundleID: "com.google.Chrome"),
        ]
        let map = DockWindowMap.windows(
            for: items, bundleIDs: [0: "com.google.Chrome", 1: "com.microsoft.VSCode"],
            processes: [.init(pid: 10, bundleID: "com.google.Chrome"), .init(pid: 20, bundleID: "com.microsoft.VSCode")],
            entries: entries
        )
        // In the store's order: most recently used first.
        #expect(map[0]?.map(\.id) == [3, 2])
        #expect(map[1]?.map(\.id) == [1])
        #expect(map[2] == nil)
    }

    @Test func eachInstanceOfAnAppHasItsOwnIcon() {
        let items = [Self.item(Self.code, y: 100), Self.item(Self.code, y: 140)]
        let entries = [
            Self.window(1, pid: 21, bundleID: "com.microsoft.VSCode"), Self.window(2, pid: 20, bundleID: "com.microsoft.VSCode"),
            Self.window(3, pid: 20, bundleID: "com.microsoft.VSCode"),
        ]
        let ids = [0: "com.microsoft.VSCode", 1: "com.microsoft.VSCode"]
        // pid 20 started first, so it has the first icon.
        let started = [DockWindowMap.Process(pid: 20, bundleID: "com.microsoft.VSCode"), .init(pid: 21, bundleID: "com.microsoft.VSCode")]
        let map = DockWindowMap.windows(for: items, bundleIDs: ids, processes: started, entries: entries)
        #expect(map[0]?.map(\.id) == [2, 3])
        #expect(map[1]?.map(\.id) == [1])
        // When the icons and processes do not pair up, each icon stands for all of them.
        let one = DockWindowMap.windows(for: items, bundleIDs: ids, processes: Array(started.prefix(1)), entries: entries)
        #expect(one[0]?.count == 3 && one[1]?.count == 3)
    }

    // MARK: Counts

    @Test func countsStartAtTwoWindows() {
        #expect(DockBadgeLayout.text(for: 0) == nil)
        #expect(DockBadgeLayout.text(for: 1) == nil)
        #expect(DockBadgeLayout.text(for: 2) == "2")
        #expect(DockBadgeLayout.text(for: 99) == "99")
        #expect(DockBadgeLayout.text(for: 140) == "99+")
    }

    @Test func aCountSitsOnTheIconsLowerCornerAwayFromTheEdge() {
        let frame = Self.item(Self.chrome).frame
        let left = DockBadgeLayout.frame(itemFrame: frame, edge: .left, textWidth: 6)
        #expect(frame.contains(left))
        #expect(left.height == 14)
        // Lower right on a Dock on the left: toward the screen, never off it.
        #expect(left.maxX > frame.midX && left.maxY == frame.maxY)
        let right = DockBadgeLayout.frame(itemFrame: frame, edge: .right, textWidth: 6)
        #expect(frame.contains(right) && right.minX < frame.midX)
        let bottomFrame = CGRect(x: 700, y: 920, width: 64, height: 70)
        let bottom = DockBadgeLayout.frame(itemFrame: bottomFrame, edge: .bottom, textWidth: 12)
        #expect(bottomFrame.contains(bottom) && bottom.maxX > bottomFrame.midX && bottom.minY > bottomFrame.midY)
        #expect(bottom.height == 20 && bottom.width >= bottom.height)
    }

    @Test func countsStepAsideWhenTheDockHidesOrMagnifies() {
        let plain = DockPreferences()
        #expect(plain.showsCounts(isHovering: false) && plain.showsCounts(isHovering: true))
        let hiding = DockPreferences(hidesAutomatically: true)
        #expect(!hiding.showsCounts(isHovering: false) && hiding.showsCounts(isHovering: true))
        let magnified = DockPreferences(magnifies: true)
        #expect(magnified.showsCounts(isHovering: false) && !magnified.showsCounts(isHovering: true))
        #expect(!DockPreferences(hidesAutomatically: true, magnifies: true).showsCounts(isHovering: true))
    }

    // MARK: The preview's layout

    private static let metrics = LayoutMetrics.thumbnails(maximumTileWidth: 220)

    @Test func aBottomDockGetsARowAndASideDockAColumn() {
        let row = DockPreviewLayout.make(
            count: 3,
            tileWidth: 220,
            edge: .bottom,
            available: CGSize(width: 1500, height: 900),
            metrics: Self.metrics
        )
        #expect(row.columns == 3 && row.rows == 1 && row.count == 3 && row.tileSize.width == 220)
        #expect(row.frame(ofTile: 2).minX > row.frame(ofTile: 1).minX && row.frame(ofTile: 2).minY == row.frame(ofTile: 0).minY)
        let column = DockPreviewLayout.make(
            count: 3,
            tileWidth: 220,
            edge: .left,
            available: CGSize(width: 1800, height: 1060),
            metrics: Self.metrics
        )
        #expect(column.columns == 1 && column.rows == 3)
        #expect(column.frame(ofTile: 2).minY > column.frame(ofTile: 1).minY && column.frame(ofTile: 2).minX == column.frame(ofTile: 0).minX)
        #expect(column.panelSize.width == 2 * DockPreviewLayout.padding + 220)
    }

    @Test func manyWindowsWrapThenShrinkThenTheMostRecentShow() {
        let wrapped = DockPreviewLayout.make(
            count: 9, tileWidth: 220, edge: .left, available: CGSize(width: 1800, height: 1060), metrics: Self.metrics
        )
        #expect(wrapped.count == 9 && wrapped.columns >= 2 && wrapped.columns * wrapped.rows >= 9)
        #expect(wrapped.panelSize.height <= 1060)
        let small = DockPreviewLayout.make(
            count: 40,
            tileWidth: 220,
            edge: .bottom,
            available: CGSize(width: 800, height: 400),
            metrics: Self.metrics
        )
        #expect(small.tileSize.width == DockPreviewLayout.minimumTileWidth)
        #expect(small.count < 40 && small.count == small.columns * small.rows)
        #expect(small.panelSize.width <= 800 && small.panelSize.height <= 400)
    }

    @Test func thePreviewSitsBesideTheIconInsideTheVisibleFrame() {
        let size = CGSize(width: 244, height: 400)
        // The dev Mac's left display in Cocoa coordinates; the Dock takes its left 55 points.
        let visible = CGRect(x: -1865, y: 0, width: 1865, height: 1080)
        let icon = CGRect(x: -1915, y: 500, width: 49, height: 37)
        let left = DockPreviewLayout.panelFrame(size: size, icon: icon, edge: .left, visibleFrame: visible)
        #expect(left.minX >= visible.minX + DockPreviewLayout.margin && abs(left.midY - icon.midY) <= 1)
        // Near the top of the screen it moves down rather than leave it.
        let high = DockPreviewLayout.panelFrame(size: size, icon: icon.offsetBy(dx: 0, dy: 520), edge: .left, visibleFrame: visible)
        #expect(high.maxY <= visible.maxY - DockPreviewLayout.margin)
        let main = CGRect(x: 0, y: 70, width: 1512, height: 879)
        let bottom = DockPreviewLayout.panelFrame(
            size: size,
            icon: CGRect(x: 10, y: 4, width: 64, height: 64),
            edge: .bottom,
            visibleFrame: main
        )
        #expect(bottom.minY >= 68 + DockPreviewLayout.gap && bottom.minX >= DockPreviewLayout.margin)
        let right = DockPreviewLayout.panelFrame(
            size: size, icon: CGRect(x: 1463, y: 400, width: 49, height: 37), edge: .right, visibleFrame: CGRect(
                x: 0,
                y: 0,
                width: 1457,
                height: 949
            )
        )
        #expect(right.maxX <= 1457 - DockPreviewLayout.margin)
    }

    // MARK: When the preview shows

    @Test func restingOnAnIconShowsItsWindowsAfterADelay() {
        var machine = DockHoverMachine()
        let chrome = Self.item(Self.chrome)
        #expect(machine.handle(.hovered(chrome)) == [.cancelScheduledHide, .scheduleShow(chrome, after: DockHoverMachine.showDelay)])
        #expect(machine.handle(.showDelayElapsed(chrome)) == [.show(chrome)])
        // Another icon while it shows: at once.
        let code = Self.item(Self.code, y: 560)
        #expect(machine.handle(.hovered(code)) == [.cancelScheduledShow, .cancelScheduledHide, .show(code)])
        #expect(machine.shown == code)
    }

    @Test func aDelayForAnIconTheMouseLeftDoesNothing() {
        var machine = DockHoverMachine()
        let chrome = Self.item(Self.chrome)
        _ = machine.handle(.hovered(chrome))
        #expect(machine.handle(.hovered(nil)) == [.cancelScheduledShow])
        #expect(machine.handle(.showDelayElapsed(chrome)).isEmpty)
        #expect(machine.shown == nil)
    }

    @Test func thePointerCanCrossFromTheIconToThePanel() {
        var machine = DockHoverMachine()
        let chrome = Self.item(Self.chrome)
        _ = machine.handle(.hovered(chrome))
        _ = machine.handle(.showDelayElapsed(chrome))
        #expect(machine.handle(.hovered(nil)) == [.cancelScheduledShow, .scheduleHide(after: DockHoverMachine.hideDelay)])
        #expect(machine.handle(.pointerEnteredPanel) == [.cancelScheduledHide])
        #expect(machine.handle(.hideDelayElapsed).isEmpty)
        #expect(machine.shown == chrome)
        // Out of the panel and back onto the icon: it stays.
        #expect(machine.handle(.pointerLeftPanel) == [.scheduleHide(after: DockHoverMachine.hideDelay)])
        #expect(machine.handle(.hovered(chrome)) == [.cancelScheduledHide])
        #expect(machine.handle(.hideDelayElapsed).isEmpty)
        // Out of both: it goes.
        _ = machine.handle(.hovered(nil))
        #expect(machine.handle(.hideDelayElapsed) == [.hide])
        #expect(machine.shown == nil)
    }

    @Test func aClickDismissesUntilThePointerMovesToAnotherIcon() {
        var machine = DockHoverMachine()
        let chrome = Self.item(Self.chrome)
        _ = machine.handle(.hovered(chrome))
        _ = machine.handle(.showDelayElapsed(chrome))
        #expect(machine.handle(.dismissed) == [.cancelScheduledShow, .cancelScheduledHide, .hide])
        // The same icon again, as the Dock reports after the click: nothing.
        #expect(machine.handle(.hovered(chrome)).isEmpty)
        let code = Self.item(Self.code, y: 560)
        #expect(machine.handle(.hovered(code)) == [.cancelScheduledHide, .scheduleShow(code, after: DockHoverMachine.showDelay)])
    }

    @Test func anAppWithNoWindowLeftHidesThePreview() {
        var machine = DockHoverMachine()
        let chrome = Self.item(Self.chrome)
        _ = machine.handle(.hovered(chrome))
        _ = machine.handle(.showDelayElapsed(chrome))
        #expect(machine.handle(.emptied) == [.cancelScheduledHide, .hide])
        #expect(machine.handle(.emptied).isEmpty)
    }

    // MARK: Settings

    @Test @MainActor func theDockFeaturesAreOnAndKeepTheModuleRunning() throws {
        let suite = "oriel.switcher.dock.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        var configuration = SwitcherConfiguration.load(from: settings)
        #expect(configuration.showsDockPreviews && configuration.showsDockWindowCounts && configuration.needsRuntime)
        settings[SwitcherSettingKeys.enabled] = false
        configuration = SwitcherConfiguration.load(from: settings)
        #expect(!configuration.isEnabled && configuration.needsRuntime)
        settings[SwitcherSettingKeys.dockPreviews] = false
        settings[SwitcherSettingKeys.dockWindowCounts] = false
        #expect(!SwitcherConfiguration.load(from: settings).needsRuntime)
    }
}
