@testable import ClipboardHistory
import Foundation
import Testing

@MainActor
struct ClipboardPanelModelTests {
    private func model(pinned: [String] = [], history: [String]) -> ClipboardPanelModel {
        var index = ClipboardIndex()
        index.pinned = pinned.map { Fixtures.item($0, source: nil) }
        index.history = history.map { Fixtures.item($0, kind: $0.hasPrefix("http") ? .link : .text, source: nil) }
        let model = ClipboardPanelModel()
        model.update(index)
        return model
    }

    private func describe(_ rows: [ClipboardRow]) -> [String] {
        rows.map { row in
            switch row {
            case let .header(section): "# \(section.title)"
            case let .item(item, _): item.title
            }
        }
    }

    @Test func headingsShowOnlyWhenThereArePinnedItems() {
        #expect(describe(model(history: ["a", "b"]).rows) == ["a", "b"])
        #expect(describe(model(pinned: ["p"], history: ["a"]).rows) == ["# Pinned", "p", "# History", "a"])
        #expect(describe(model(pinned: ["p"], history: []).rows) == ["# Pinned", "p"])
    }

    @Test func searchAndTypeFilterNarrowTheRows() {
        let model = model(pinned: ["pinned note"], history: ["https://example.com", "note to self", "groceries"])
        model.query = "note"
        #expect(describe(model.rows) == ["# Pinned", "pinned note", "# History", "note to self"])
        #expect(model.isFiltering)
        model.query = ""
        model.filter = .links
        #expect(describe(model.rows) == ["https://example.com"])
        model.filter = .pinned
        #expect(describe(model.rows) == ["# Pinned", "pinned note"])
        model.filter = .all
        #expect(!model.isFiltering)
    }

    @Test func theNewestCopyIsSelectedFirstAndTheFirstNineAreNumbered() {
        let model = model(pinned: ["p1", "p2"], history: (1 ... 10).map { "h\($0)" })
        #expect(model.initialRow == 4)
        #expect(model.item(at: 4)?.title == "h1")
        #expect(model.quickPasteNumber(forRow: 1) == 1)
        #expect(model.quickPasteNumber(forRow: 4) == 3)
        #expect(model.item(quickPasteNumber: 9)?.title == "h7")
        #expect(model.item(quickPasteNumber: 10) == nil)
        #expect(model.quickPasteNumber(forRow: 0) == nil)
    }

    @Test func dropsLandInTheSectionAndPlaceAboveTheRow() {
        let model = model(pinned: ["p1", "p2"], history: ["a", "b"])
        // Rows: 0 # Pinned, 1 p1, 2 p2, 3 # History, 4 a, 5 b.
        #expect(model.dropDestination(aboveRow: 0) == (.pinned, 0))
        #expect(model.dropDestination(aboveRow: 2) == (.pinned, 1))
        #expect(model.dropDestination(aboveRow: 3) == (.pinned, 2))
        #expect(model.dropDestination(aboveRow: 5) == (.history, 1))
        #expect(model.dropDestination(aboveRow: 6) == (.history, 2))
        let pinnedOnly = self.model(pinned: ["p"], history: [])
        #expect(pinnedOnly.dropDestination(aboveRow: 2) == (.pinned, 1))
    }

    @Test func afterDeletingTheNextItemIsSelected() {
        let model = model(pinned: ["p"], history: ["a"])
        #expect(model.nearestItemRow(to: 2) == 3)
        #expect(model.nearestItemRow(to: 9) == 3)
        #expect(ClipboardPanelModel().nearestItemRow(to: 0) == nil)
    }
}
