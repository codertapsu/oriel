import CoreGraphics
import Foundation
import OrielCore
import Testing
@testable import WindowSwitcher

/// Shortcut filters (PLAN §7.1.4) and the eligibility rules (PLAN §7.1.1 item 4), as table tests.
struct FilterTests {
    static let left = DisplayInfo(id: 2, bounds: CGRect(x: -1920, y: 0, width: 1920, height: 1080))
    static let main = DisplayInfo(id: 1, bounds: CGRect(x: 0, y: 0, width: 1512, height: 982))

    static let windows = [
        Fixture.entry(1, pid: 10, app: "Safari", display: 1),
        Fixture.entry(2, pid: 10, app: "Safari", minimized: true, display: 1),
        Fixture.entry(3, pid: 20, app: "Notes", hidden: true, display: 1),
        Fixture.entry(4, pid: 20, app: "Notes", currentSpace: false, space: 2, display: 1),
        // No display from SkyLight: placed by its frame on the left display.
        Fixture.entry(5, pid: 30, app: "Mail", frame: CGRect(x: -1500, y: 100, width: 800, height: 600)),
        Fixture.entry(6, pid: 30, app: "Mail", display: 2),
    ]

    static let context = FilterContext(activePID: 20, screenDisplayID: 1, displays: [left, main])

    @Test(arguments: [
        (WindowFilter(), [UInt32]([1, 2, 3, 4, 5, 6])),
        (WindowFilter(apps: .active), [3, 4]),
        (WindowFilter(spaces: .current), [1, 2, 3, 5, 6]),
        (WindowFilter(screens: .current), [1, 2, 3, 4]),
        (WindowFilter(minimized: .exclude), [1, 3, 4, 5, 6]),
        (WindowFilter(hidden: .exclude), [1, 2, 4, 5, 6]),
        (WindowFilter(apps: .active, spaces: .current), [3]),
        (WindowFilter(spaces: .current, screens: .current, minimized: .exclude, hidden: .exclude), [1]),
    ])
    func filtersKeepTheRightWindows(_ filter: WindowFilter, _ expected: [UInt32]) {
        #expect(filter.apply(to: Self.windows, context: Self.context).map(\.id) == expected)
    }

    @Test func theScreenFilterUsesFramesWhenSkyLightGaveNoDisplay() {
        let context = FilterContext(activePID: nil, screenDisplayID: 2, displays: [Self.left, Self.main])
        #expect(WindowFilter(screens: .current).apply(to: Self.windows, context: context).map(\.id) == [5, 6])
    }

    @Test func filtersSurviveSettingsFromOlderBuilds() throws {
        let decoded = try JSONDecoder().decode(WindowFilter.self, from: Data(#"{"apps":"active"}"#.utf8))
        #expect(decoded == WindowFilter(apps: .active))
    }

    @Test(arguments: [
        (AXWindowRecord(windowID: 1, title: "Doc"), 0, true),
        (AXWindowRecord(windowID: 1, title: "Alert", subrole: "AXDialog"), 0, true),
        (AXWindowRecord(windowID: 1, title: "Palette", subrole: "AXFloatingWindow"), 0, false),
        (AXWindowRecord(windowID: 1, title: "", subrole: "AXUnknown"), 0, false),
        (AXWindowRecord(windowID: 1, title: "", subrole: nil), 0, false),
        (AXWindowRecord(windowID: 1, title: "Sheet", role: "AXSheet"), 0, false),
        (AXWindowRecord(windowID: 1, title: "Doc"), 3, false),
    ])
    func onlyStandardWindowsAndDialogsAtLayerZeroCount(_ record: AXWindowRecord, _ layer: Int, _ accepted: Bool) {
        let rules = EligibilityRules()
        #expect(rules.accepts(record, layer: layer, frame: CGRect(x: 0, y: 0, width: 400, height: 300)) == accepted)
    }

    @Test(arguments: [
        (CGSize(width: 1512, height: 33), false),
        (CGSize(width: 49, height: 400), false),
        (CGSize(width: 50, height: 50), true),
        (CGSize(width: 500, height: 500), true),
    ])
    func tinyWindowsDoNotCount(_ size: CGSize, _ accepted: Bool) {
        let rules = EligibilityRules()
        #expect(rules.accepts(AXWindowRecord(windowID: 1, title: "W"), layer: 0, frame: CGRect(origin: .zero, size: size)) == accepted)
        #expect(rules.accepts(ServerWindowRecord(id: 1, pid: 1, frame: CGRect(origin: .zero, size: size))) == accepted)
    }

    @Test func invisibleServerWindowsDoNotCount() {
        let rules = EligibilityRules()
        #expect(!rules.accepts(ServerWindowRecord(id: 1, pid: 1, frame: CGRect(x: 0, y: 0, width: 594, height: 300), alpha: 0)))
        #expect(!rules.accepts(ServerWindowRecord(id: 1, pid: 1, layer: 25, frame: CGRect(x: 0, y: 0, width: 594, height: 300))))
    }
}
