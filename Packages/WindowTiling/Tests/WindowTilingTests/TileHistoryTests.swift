import CoreGraphics
import Testing
@testable import WindowTiling

/// Restore bookkeeping: a run of actions keeps the frame from before the first; moving the window by hand starts a
/// new run; the history forgets the least recently arranged windows first.
struct TileHistoryTests {
    private static let original = CGRect(x: 300, y: 200, width: 700, height: 500)
    private static let left = CGRect(x: 0, y: 33, width: 756, height: 879)
    private static let maximized = CGRect(x: 0, y: 33, width: 1512, height: 879)

    @Test func aRunOfActionsKeepsTheFrameFromBeforeTheFirst() throws {
        var history = TileHistory<Int>()
        history.noteArranged(1, from: Self.original, previous: nil, action: .leftHalf, step: 0, target: Self.left, result: Self.left)
        let record = try #require(history.record(for: 1, at: Self.left))
        #expect(record.restoreFrame == Self.original && record.action == .leftHalf)
        history.noteArranged(
            1,
            from: Self.left,
            previous: record,
            action: .maximize,
            step: 0,
            target: Self.maximized,
            result: Self.maximized
        )
        #expect(history.restoreFrame(for: 1) == Self.original)
        #expect(history.record(for: 1, at: Self.maximized)?.action == .maximize)
    }

    @Test func movingTheWindowByHandStartsANewRun() {
        var history = TileHistory<Int>()
        history.noteArranged(1, from: Self.original, previous: nil, action: .leftHalf, step: 0, target: Self.left, result: Self.left)
        let dragged = CGRect(x: 40, y: 90, width: 756, height: 879)
        // Not where Window Tiling left it: no current record, so the next action records the dragged frame.
        #expect(history.record(for: 1, at: dragged) == nil)
        history.noteArranged(
            1,
            from: dragged,
            previous: history.record(for: 1, at: dragged),
            action: .rightHalf,
            step: 0,
            target: Self.left,
            result: Self.left
        )
        #expect(history.restoreFrame(for: 1) == dragged)
    }

    @Test func aWindowCountsAsUntouchedNearItsTargetOrItsResult() {
        var history = TileHistory<Int>()
        // A terminal snapped the target to whole characters.
        let snapped = CGRect(x: 0, y: 33, width: 749, height: 875)
        history.noteArranged(1, from: Self.original, previous: nil, action: .leftHalf, step: 0, target: Self.left, result: snapped)
        #expect(history.record(for: 1, at: snapped) != nil)
        #expect(history.record(for: 1, at: Self.left) != nil)
        #expect(history.record(for: 1, at: snapped.offsetBy(dx: 1, dy: 1)) != nil)
        #expect(history.record(for: 1, at: snapped.offsetBy(dx: 3, dy: 0)) == nil)
    }

    @Test func restoreFramesOutliveAMoveByHandUntilForgotten() {
        var history = TileHistory<Int>()
        history.noteArranged(1, from: Self.original, previous: nil, action: .leftHalf, step: 0, target: Self.left, result: Self.left)
        #expect(history.restoreFrame(for: 1) == Self.original)
        history.forget(1)
        #expect(history.restoreFrame(for: 1) == nil)
        #expect(history.count == 0)
    }

    @Test func theLeastRecentlyArrangedWindowIsDroppedFirst() {
        var history = TileHistory<Int>(capacity: 3)
        for id in 1 ... 3 {
            history.noteArranged(id, from: Self.original, previous: nil, action: .center, step: 0, target: Self.left, result: Self.left)
        }
        // Arranging 1 again makes 2 the oldest.
        history.noteArranged(1, from: Self.left, previous: nil, action: .center, step: 0, target: Self.left, result: Self.left)
        history.noteArranged(4, from: Self.original, previous: nil, action: .center, step: 0, target: Self.left, result: Self.left)
        #expect(history.count == 3)
        #expect(history.restoreFrame(for: 2) == nil)
        #expect(history.restoreFrame(for: 1) != nil && history.restoreFrame(for: 3) != nil && history.restoreFrame(for: 4) != nil)
        history.removeAll()
        #expect(history.count == 0)
    }

    @Test func theCapacityIsAtLeastOne() {
        var history = TileHistory<Int>(capacity: 0)
        history.noteArranged(1, from: Self.original, previous: nil, action: .center, step: 0, target: Self.left, result: Self.left)
        #expect(history.count == 1 && history.capacity == 1)
    }
}
