import CoreGraphics
import OrielCore
import Testing
@testable import WindowSwitcher

/// The pure merge rules behind `WindowStore` (PLAN §7.1.1, §7.1.2 fallbacks).
struct WindowMergerTests {
    @Test func withoutWindowIDsAXWindowsAreMatchedByFrame() {
        let frame = CGRect(x: 10, y: 20, width: 640, height: 480)
        let input = MergeInput(
            apps: [AppRecord(pid: 1, bundleID: nil, name: "App")],
            axWindows: [1: [AXWindowRecord(windowID: nil, title: "Doc", frame: frame)]],
            serverWindows: [
                ServerWindowRecord(id: 7, pid: 1, frame: CGRect(x: 0, y: 0, width: 100, height: 100)),
                ServerWindowRecord(id: 8, pid: 1, frame: frame.offsetBy(dx: 1, dy: 1)),
            ],
            spaces: nil
        )
        #expect(WindowMerger.merge(input).map(\.id) == [8])
    }

    @Test func unlistedRecordsNeedAnotherSpaceAMinimizedWindowOrAHiddenApp() {
        let spaces = SpaceSnapshot(
            displays: [SpaceSnapshot.Display(displayID: 1, currentSpaceID: 1, spaceIDs: [1, 2])],
            windowSpaces: [1: [1], 2: [2], 3: []]
        )
        let frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let ids: [UInt32] = [1, 2, 3]
        func merged(hidden: Bool) -> [UInt32] {
            let input = MergeInput(
                apps: [AppRecord(pid: 1, bundleID: nil, name: "App", isHidden: hidden)],
                axWindows: [1: ids.map { AXWindowRecord(windowID: $0, title: "W\($0)", isListed: false) }],
                serverWindows: ids.map { ServerWindowRecord(id: $0, pid: 1, frame: frame) },
                spaces: spaces
            )
            return WindowMerger.merge(input).map(\.id)
        }
        // 1 is on the visible Space but AX did not list it (an inactive tab); 3 is on no Space.
        #expect(merged(hidden: false) == [2])
        #expect(merged(hidden: true) == [1, 2, 3])
    }

    @Test func titlesFallBackToTheServerThenTheAppName() {
        let frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let input = MergeInput(
            apps: [AppRecord(pid: 1, bundleID: nil, name: "App")],
            axWindows: [1: [AXWindowRecord(windowID: 1, title: ""), AXWindowRecord(windowID: 2, title: "")]],
            serverWindows: [
                ServerWindowRecord(id: 1, pid: 1, frame: frame, title: "Server Title"),
                ServerWindowRecord(id: 2, pid: 1, frame: frame),
            ],
            spaces: nil
        )
        #expect(WindowMerger.merge(input).map(\.info.title) == ["Server Title", "App"])
    }

    @Test func otherSpaceCandidatesSkipHelpersAndVisibleWindows() {
        let candidates = WindowMerger.otherSpaceCandidates(
            of: Fixture.apps[0], listed: [10], serverWindows: Fixture.server, spaces: Fixture.spaces, rules: EligibilityRules()
        )
        #expect(candidates == [11, 14])
        // A hidden app's windows on the visible Space count too; helpers on no Space still do not.
        var hidden = Fixture.apps[0]
        hidden.isHidden = true
        let hiddenCandidates = WindowMerger.otherSpaceCandidates(
            of: hidden, listed: [10], serverWindows: Fixture.server, spaces: Fixture.spaces, rules: EligibilityRules()
        )
        #expect(hiddenCandidates == [11, 14, 15])
    }
}
