import Hotkeys
import OrielCore
import Testing
@testable import WindowSwitcher

/// Windows grouped by app (PLAN §7.1.11) as pure functions: the order, the groups, the first selection, and which app the
/// quit key reaches.
struct GroupingTests {
    /// Most recent first: Safari is in front, then Notes, Safari again, Mail, Notes again.
    private static let windows = [
        Fixture.entry(1, pid: 10, app: "Safari", title: "Apple"),
        Fixture.entry(2, pid: 20, app: "Notes", title: "Shopping"),
        Fixture.entry(3, pid: 10, app: "Safari", title: "GitHub"),
        Fixture.entry(4, pid: 30, app: "Mail", title: "Inbox"),
        Fixture.entry(5, pid: 20, app: "Notes", title: "Recipes"),
    ]

    private func items(_ style: DisplayStyle = .thumbnails, query: String = "", grouping: WindowGrouping = .byApp) -> [SwitcherItem] {
        SwitcherItemBuilder.items(from: Self.windows, style: style, query: query, grouping: grouping)
    }

    @Test func appsFollowTheirMostRecentWindowAndKeepTheirWindowsInOrder() {
        #expect(items().map(\.id) == [1, 3, 2, 5, 4])
        #expect(items(grouping: .ungrouped).map(\.id) == [1, 2, 3, 4, 5])
    }

    @Test func aSearchKeepsTheBestMatchFirstWithItsAppAfterIt() {
        // "s" matches four windows of all three apps but Mail.
        let ranked = items(query: "s", grouping: .ungrouped)
        let grouped = items(query: "s")
        #expect(ranked.count == 4)
        #expect(grouped.first?.id == ranked.first?.id)
        #expect(Set(grouped.map(\.id)) == Set(ranked.map(\.id)))
        for pid in Set(grouped.map(\.entry.info.pid)) {
            let offsets = grouped.indices.filter { grouped[$0].entry.info.pid == pid }
            guard let first = offsets.first, let last = offsets.last else { continue }
            #expect(last - first + 1 == offsets.count, "the windows of \(pid) are not together")
        }
    }

    @Test func groupsAreTheRunsOfOneApp() {
        let groups = SwitcherItemBuilder.groups(of: items())
        #expect(groups.map(\.appName) == ["Safari", "Notes", "Mail"])
        #expect(groups.map(\.items) == [0 ..< 2, 2 ..< 4, 4 ..< 5])
        #expect(groups.first?.bundleID == "com.example.safari")
        #expect(SwitcherItemBuilder.groups(of: []).isEmpty)
    }

    @Test func titleRowsLeaveTheAppNameToTheHeader() {
        #expect(items(.titles).allSatisfy { !$0.showsAppName })
        let ungroupedShowNames = items(.titles, grouping: .ungrouped).allSatisfy(\.showsAppName)
        #expect(ungroupedShowNames)
        // VoiceOver still hears the app with every window.
        #expect(items(.titles).first?.accessibilityLabel == "Apple — Safari")
    }

    @Test func theAppIconsStyleIsOneTilePerAppAnyway() {
        #expect(items(.appIcons).map(\.id) == items(.appIcons, grouping: .ungrouped).map(\.id))
    }

    @Test func aQuickPressStillGoesToThePreviousWindow() {
        let grouped = items()
        let start = SwitcherItemBuilder.initialSelection(in: grouped, windows: Self.windows)
        // The previous window (Notes "Shopping") sits third once grouped; the least recent (Notes "Recipes") fourth.
        #expect(start == SwitcherStateMachine.InitialSelection(forward: 2, backward: 3))
        #expect(SwitcherItemBuilder.initialSelection(in: grouped, windows: Array(Self.windows.prefix(1))) == nil)

        var machine = SwitcherStateMachine()
        _ = machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option))
        #expect(machine.setItems(count: grouped.count, columns: 5, initial: start) == [.select(2)])
        #expect(machine.handle(.flagsChanged([])).effects == [.commit(index: 2)])
        #expect(grouped[2].id == Self.windows[1].id)
    }

    @Test func theReverseShortcutStartsOnTheLeastRecentWindow() {
        let grouped = items()
        var machine = SwitcherStateMachine()
        _ = machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: [.option, .shift]))
        let start = SwitcherItemBuilder.initialSelection(in: grouped, windows: Self.windows)
        #expect(machine.setItems(count: grouped.count, columns: 5, initial: start) == [.select(3)])
        // The first selection is placed once; later updates keep the selected window.
        #expect(machine.setItems(count: grouped.count, columns: 5, selecting: 3, initial: start) == [.select(3)])
    }

    @Test func anOutOfRangeStartIsClamped() {
        var machine = SwitcherStateMachine()
        _ = machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option))
        let start = SwitcherStateMachine.InitialSelection(forward: 9, backward: 0)
        #expect(machine.setItems(count: 3, columns: 3, initial: start) == [.select(2)])
    }

    // MARK: Quitting from the switcher

    @Test(arguments: [KeyCombo.Modifiers.option, .command, .control, [.option, .shift]])
    func qWithACommandModifierQuitsTheSelectedApp(_ modifiers: KeyCombo.Modifiers) {
        var machine = SwitcherStateMachine()
        _ = machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option))
        _ = machine.setItems(count: 4, columns: 4)
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiQ, modifiers: modifiers)) == .consume([.quitApp(index: 1)]))
        // Held down, it does not quit again; the switcher stays open.
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiQ, modifiers: modifiers, isRepeat: true)).effects == [])
        #expect(machine.isOpen)
    }

    @Test func plainQTypesIntoTheSearch() {
        var keepOpen = ShortcutSpec.optionTab
        keepOpen.releaseBehavior = .keepOpen
        var machine = SwitcherStateMachine(shortcuts: [keepOpen])
        _ = machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option))
        _ = machine.setItems(count: 4, columns: 4)
        _ = machine.handle(.flagsChanged([]))
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiQ, modifiers: [], characters: "q")).effects == [.search("q")])
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiQ, modifiers: .shift, characters: "Q")).effects == [.search("qQ")])
    }

    @Test func quitReachesTheAppOfTheSelectedTileInEveryArrangement() {
        // Grouped: the selected item is the previous window, and the app quit is that window's.
        let grouped = items()
        let start = SwitcherItemBuilder.initialSelection(in: grouped, windows: Self.windows)
        var machine = SwitcherStateMachine()
        _ = machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option))
        _ = machine.setItems(count: grouped.count, columns: 5, initial: start)
        guard case let .quitApp(index) = machine.handle(.keyDown(keyCode: KeyCode.ansiQ, modifiers: .option)).effects.first else {
            Issue.record("no quit")
            return
        }
        #expect(grouped[index].entry.info.pid == 20)
        // App icons: one tile per app, so the second tile is the second app.
        let apps = items(.appIcons)
        #expect(apps[1].entry.info.pid == 20)
    }

    @Test func nothingToQuitWithAnEmptyList() {
        var machine = SwitcherStateMachine()
        _ = machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option))
        _ = machine.setItems(count: 0, columns: 1)
        #expect(machine.handle(.keyDown(keyCode: KeyCode.ansiQ, modifiers: .option)).effects == [])
    }

    // MARK: Key hints

    @Test func theHintsNameTheKeysWithTheShortcutsModifiers() {
        let hints = KeyHint.windowActions(holding: .option)
        #expect(hints.map(\.keys) == ["⌥W", "⌥M", "⌥F", "⌥Q"])
        #expect(hints.map(\.label) == ["Close", "Minimize", "Full Screen", "Quit App"])
        #expect(KeyHint.windowActions(holding: .command).last?.keys == "⌘Q")
        #expect(KeyHint.windowActions(holding: [.control, .option, .shift]).first?.keys == "⌃⌥W")
        // A shortcut held with ⇧ alone: any command modifier works, so the line shows ⌥.
        #expect(KeyHint.windowActions(holding: .shift).first?.keys == "⌥W")
    }
}
