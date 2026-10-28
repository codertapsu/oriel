import AppKit
import SharedUI
import Testing
@testable import WindowSwitcher

/// Tiles are accessibility buttons labelled "Title — App, minimized, Space 2" (PLAN §7.1.9), and badges
/// say where each window is. Views are built but never put in a window.
@MainActor
struct AccessibilityTests {
    private let plain = AccessibilityDisplay(reduceTransparency: false, increaseContrast: false, reduceMotion: false)

    @Test func labelsReadTitleAppAndState() {
        let badges: [WindowBadge] = [.minimized, .space(2)]
        #expect(SwitcherItem.accessibilityLabel(title: "Title", appName: "App", badges: badges) == "Title — App, minimized, Space 2")
        #expect(SwitcherItem.accessibilityLabel(title: "Safari", appName: "Safari", badges: []) == "Safari")
        #expect(SwitcherItem.accessibilityLabel(title: "", appName: "Mail", badges: [.hidden], windowCount: 3) == "Mail, 3 windows, hidden")
    }

    @Test(arguments: [DisplayStyle.thumbnails, .appIcons, .titles])
    func everyTileStyleIsAButtonWithTheLabel(_ style: DisplayStyle) throws {
        let entry = Fixture.entry(1, app: "Pages", title: "Report", minimized: true, currentSpace: false, space: 2)
        let item = try #require(SwitcherItemBuilder.items(from: [entry], style: style, query: "").first)
        let tile: TileView = switch style {
        case .thumbnails: WindowTileView(frame: CGRect(x: 0, y: 0, width: 220, height: 163))
        case .appIcons: AppIconTileView(frame: CGRect(x: 0, y: 0, width: 104, height: 106))
        case .titles: TitleRowView(frame: CGRect(x: 0, y: 0, width: 600, height: 30))
        }
        tile.configure(item, icon: nil, display: plain)
        tile.layoutSubtreeIfNeeded()
        #expect(tile.isAccessibilityElement())
        #expect(tile.accessibilityRole() == .button)
        let expected = style == .appIcons ? "Pages, minimized, Space 2" : "Report — Pages, minimized, Space 2"
        #expect(tile.accessibilityLabel() == expected)
        tile.isSelected = true
        #expect(tile.isAccessibilitySelected())
    }

    @Test func pressingATileThroughAccessibilityClicksIt() throws {
        let item = try #require(SwitcherItemBuilder.items(from: [Fixture.entry(1)], style: .thumbnails, query: "").first)
        let tile = WindowTileView(frame: CGRect(x: 0, y: 0, width: 220, height: 163))
        tile.configure(item, icon: nil, display: plain)
        var clicks = 0
        tile.onClick = { clicks += 1 }
        #expect(tile.accessibilityPerformPress())
        #expect(clicks == 1)
    }

    @Test func hoverButtonsMatchTheWindowsState() {
        #expect(TileAction.actions(isMinimized: false) == [.close, .minimize, .toggleFullScreen])
        #expect(TileAction.actions(isMinimized: true) == [.close, .restore, .toggleFullScreen])
        let bar = TileActionBar()
        bar.configure(isMinimized: false)
        #expect(bar.fittingWidth == 3 * TileActionButton.side + 2 * 4)
    }

    @Test(arguments: [
        (Fixture.entry(1), [WindowBadge]()),
        (Fixture.entry(1, minimized: true), [.minimized]),
        (Fixture.entry(1, hidden: true), [.hidden]),
        (Fixture.entry(1, currentSpace: false, space: 3), [.space(3)]),
        (Fixture.entry(1, currentSpace: false), [.otherSpace]),
        (Fixture.entry(1, fullScreen: true, currentSpace: false, space: 4), [.fullScreen]),
        (Fixture.entry(1, minimized: true, hidden: true, currentSpace: false, space: 2), [.minimized, .hidden, .space(2)]),
    ])
    func badgesSayWhereTheWindowIs(_ entry: WindowEntry, _ badges: [WindowBadge]) {
        #expect(WindowBadge.badges(for: entry.info) == badges)
    }

    @Test func badgeLabelsNumberSpacesAndDisplays() {
        #expect(WindowBadge.space(3).label == "Space 3")
        #expect(WindowBadge.display(2).label == "Display 2")
        #expect(WindowBadge.fullScreen.label == "Full Screen")
        #expect(WindowBadge.otherSpace.spokenLabel == "on another Space")
    }

    @Test func windowsOnAnotherDisplayGetADisplayBadge() {
        let entries = [Fixture.entry(1, display: 1), Fixture.entry(2, display: 2)]
        let items = SwitcherItemBuilder.items(from: entries, style: .thumbnails, query: "", displayNumbers: [1: 2, 2: 1], panelDisplayID: 1)
        #expect(items.map(\.badges) == [[], [.display(1)]])
        // One display: no display badges.
        let single = SwitcherItemBuilder.items(from: entries, style: .thumbnails, query: "", displayNumbers: [1: 1], panelDisplayID: 1)
        let noBadges = single.allSatisfy(\.badges.isEmpty)
        #expect(noBadges)
    }

    @Test func displaysAreNumberedLeftToRight() {
        let displays = [
            DisplayInfo(id: 1, bounds: CGRect(x: 0, y: 0, width: 1512, height: 982)),
            DisplayInfo(id: 2, bounds: CGRect(x: -1920, y: 0, width: 1920, height: 1080)),
            DisplayInfo(id: 3, bounds: CGRect(x: 1512, y: 0, width: 2560, height: 1440)),
        ]
        #expect(DisplayInfo.numbers(for: displays) == [2: 1, 1: 2, 3: 3])
    }

    @Test func appIconItemsGroupWindowsByApp() {
        let entries = [
            Fixture.entry(1, pid: 10, app: "Safari", title: "A"),
            Fixture.entry(2, pid: 20, app: "Notes", title: "B"),
            Fixture.entry(3, pid: 10, app: "Safari", title: "C"),
        ]
        let items = SwitcherItemBuilder.items(from: entries, style: .appIcons, query: "")
        #expect(items.map(\.id) == [1, 2])
        #expect(items.map(\.windowCount) == [2, 1])
        #expect(items.first?.accessibilityLabel == "Safari, 2 windows")
        // Search picks each app's best window.
        let searched = SwitcherItemBuilder.items(from: entries, style: .appIcons, query: "c")
        #expect(searched.map(\.id) == [3])
    }
}
