@testable import ClipboardHistory
import Foundation
import Testing

struct ClipboardIndexTests {
    private func index(pinned: [String] = [], history: [String]) -> ClipboardIndex {
        var index = ClipboardIndex()
        index.pinned = pinned.map { Fixtures.item($0) }
        index.history = history.map { Fixtures.item($0) }
        return index
    }

    private func titles(_ items: [ClipboardItem]) -> [String] {
        items.map(\.title)
    }

    @Test func newCopiesGoOnTop() {
        var index = index(history: ["b", "c"])
        let result = index.record(Fixtures.item("a"))
        #expect(result.isNew)
        #expect(titles(index.history) == ["a", "b", "c"])
    }

    @Test func aRepeatCopyMovesToTheTopAndKeepsItsIdentity() throws {
        var index = index(history: ["a", "b", "c"])
        let original = index.history[2]
        let later = Date().addingTimeInterval(60)
        let result = index.record(Fixtures.item("c", date: later, source: "Safari"))
        #expect(!result.isNew)
        #expect(titles(index.history) == ["c", "a", "b"])
        let kept = try #require(index.history.first)
        #expect(kept.id == original.id)
        #expect(kept.copyCount == 2)
        #expect(kept.sourceName == "Safari")
        #expect(kept.lastCopied == later)
        #expect(kept.firstCopied == original.firstCopied)
    }

    @Test func aRepeatOfAPinnedItemLeavesItWhereItIs() {
        var index = index(pinned: ["x", "y"], history: ["a"])
        let result = index.record(Fixtures.item("y"))
        #expect(!result.isNew)
        #expect(titles(index.pinned) == ["x", "y"])
        #expect(index.pinned[1].copyCount == 2)
        #expect(titles(index.history) == ["a"])
    }

    @Test func removedItemsComeBackWhereTheyWere() {
        var index = index(pinned: ["p1", "p2", "p3"], history: ["a", "b", "c", "d"])
        let before = index
        let ids = Set([index.pinned[1].id, index.history[0].id, index.history[2].id])
        let removals = index.remove(ids)
        #expect(removals.count == 3)
        #expect(titles(index.pinned) == ["p1", "p3"])
        #expect(titles(index.history) == ["b", "d"])
        index.restore(removals.reversed())
        #expect(index == before)
    }

    @Test func movingWithinASectionPutsItemsBeforeTheTarget() {
        var index = index(history: ["a", "b", "c", "d", "e"])
        index.move([index.history[3].id, index.history[0].id], to: .history, at: 2)
        #expect(titles(index.history) == ["b", "a", "d", "c", "e"])
        index.move([index.history[0].id], to: .history, at: index.history.count)
        #expect(titles(index.history) == ["a", "d", "c", "e", "b"])
    }

    @Test func movingIntoPinnedPinsAndOutUnpins() {
        var index = index(pinned: ["p"], history: ["a", "b"])
        index.move([index.history[1].id], to: .pinned, at: 0)
        #expect(titles(index.pinned) == ["b", "p"])
        #expect(titles(index.history) == ["a"])
        index.move([index.pinned[1].id], to: .history, at: 1)
        #expect(titles(index.pinned) == ["b"])
        #expect(titles(index.history) == ["a", "p"])
    }

    @Test func pinningAppendsAndUnpinningGoesToTheTop() {
        var index = index(pinned: ["p"], history: ["a", "b", "c"])
        index.setPinned([index.history[2].id, index.history[0].id, index.pinned[0].id], true)
        #expect(titles(index.pinned) == ["p", "a", "c"])
        #expect(titles(index.history) == ["b"])
        index.setPinned([index.pinned[1].id], false)
        #expect(titles(index.pinned) == ["p", "c"])
        #expect(titles(index.history) == ["a", "b"])
    }

    @Test func touchingMovesAHistoryItemUpButNotAPinnedOne() {
        var index = index(pinned: ["p1", "p2"], history: ["a", "b"])
        let now = Date().addingTimeInterval(100)
        index.touch(index.history[1].id, at: now)
        #expect(titles(index.history) == ["b", "a"])
        #expect(index.history[0].lastCopied == now)
        index.touch(index.pinned[1].id, at: now)
        #expect(titles(index.pinned) == ["p1", "p2"])
        #expect(index.pinned[1].lastCopied == now)
    }

    @Test func pruningDropsOldAndOverflowingHistoryButNeverPinned() {
        let now = Date()
        var index = ClipboardIndex()
        index.pinned = [Fixtures.item("ancient pin", date: now.addingTimeInterval(-400 * 86400))]
        index.history = [
            Fixtures.item("fresh", date: now),
            Fixtures.item("week", date: now.addingTimeInterval(-6 * 86400)),
            Fixtures.item("month", date: now.addingTimeInterval(-40 * 86400)),
            Fixtures.item("recent", date: now.addingTimeInterval(-1 * 86400)),
        ]
        let expired = index.prune(ClipboardLimits(items: 0, days: 30, bytes: 0), now: now)
        #expect(titles(expired) == ["month"])
        let overflow = index.prune(ClipboardLimits(items: 2, days: 0, bytes: 0), now: now)
        #expect(titles(overflow) == ["recent"])
        #expect(titles(index.history) == ["fresh", "week"])
        #expect(titles(index.pinned) == ["ancient pin"])
    }

    /// Screenshots are big: past the size limit the oldest history items go, and pinned ones count but stay.
    @Test func pruningKeepsTheHistoryUnderItsSizeButNeverDropsPinned() {
        var index = ClipboardIndex()
        index.pinned = [Fixtures.item("pinned")]
        index.history = ["new", "middle", "old"].map { Fixtures.item($0) }
        index.pinned[0].byteCount = 400
        for position in index.history.indices {
            index.history[position].byteCount = 300
        }
        let removed = index.prune(ClipboardLimits(items: 0, days: 0, bytes: 999), now: Date())
        #expect(titles(removed) == ["old", "middle"])
        #expect(titles(index.history) == ["new"])
        let more = index.prune(ClipboardLimits(items: 0, days: 0, bytes: 100), now: Date())
        #expect(titles(more) == ["new"])
        #expect(titles(index.pinned) == ["pinned"])
    }
}
