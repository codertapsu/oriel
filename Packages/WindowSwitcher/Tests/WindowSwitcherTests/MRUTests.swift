import Testing
@testable import WindowSwitcher

/// Most-recently-used order, in memory (PLAN §7.1.1 item 5).
struct MRUTests {
    @Test func touchingMovesAWindowToTheFront() {
        var mru = MRUList([1, 2, 3])
        mru.touch(3)
        #expect(mru.ids == [3, 1, 2])
        mru.touch(9)
        #expect(mru.ids == [9, 3, 1, 2])
    }

    @Test func duplicatesCollapse() {
        #expect(MRUList([1, 2, 1, 3, 2]).ids == [1, 2, 3])
    }

    @Test func removingAndPruningForgetWindows() {
        var mru = MRUList([1, 2, 3, 4])
        mru.remove(2)
        #expect(mru.ids == [1, 3, 4])
        mru.prune(keeping: [4, 1])
        #expect(mru.ids == [1, 4])
    }

    @Test func seedingAppendsOnlyUnknownWindows() {
        var mru = MRUList([5, 1])
        mru.seed([1, 2, 5, 3])
        #expect(mru.ids == [5, 1, 2, 3])
    }

    @Test func sortingPutsKnownWindowsFirstAndKeepsTheRestInOrder() {
        let mru = MRUList([30, 10])
        let windows: [UInt32] = [10, 20, 30, 40, 50]
        #expect(mru.sorted(windows) { $0 } == [30, 10, 20, 40, 50])
        #expect(MRUList().sorted(windows) { $0 } == windows)
    }
}
