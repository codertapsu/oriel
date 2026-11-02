import Foundation
import OrielCore

/// What the panel lists for the current search and type filter: the pinned items under a Pinned heading, then the
/// history, under a History heading only when Pinned shows too. Built from the store's index; no AppKit, so tested
/// directly. Without Oriel Pro it lists the last `freeCount` items from the past `freeDays` days, searches no text read
/// from images and numbers no item for ⌘1…⌘9 (PLAN §19).
final class ClipboardPanelModel {
    static let freeCount = 100
    static let freeDays = 7
    /// How many items stay pinned without Oriel Pro.
    static let freePins = 5

    /// Whether a Pro feature is unlocked; tests hand in their own answer.
    var allows: (ProFeature) -> Bool = { ProAccess.shared.allows($0) }
    var now: () -> Date = Date.init

    private(set) var index = ClipboardIndex()
    private(set) var rows: [ClipboardRow] = []
    /// Row → its ⌘-number, for the first nine items shown.
    private var quickPasteNumbers: [Int: Int] = [:]

    var query = "" {
        didSet {
            if query != oldValue {
                rebuild()
            }
        }
    }

    var filter = ClipboardFilter.all {
        didSet {
            if filter != oldValue {
                rebuild()
            }
        }
    }

    func update(_ index: ClipboardIndex) {
        self.index = index
        rebuild()
    }

    /// Whether a search or type filter hides anything, which turns reordering off.
    var isFiltering: Bool {
        !ClipboardSearch.terms(in: query).isEmpty || filter != .all
    }

    func item(at row: Int) -> ClipboardItem? {
        rows.indices.contains(row) ? rows[row].item : nil
    }

    func section(at row: Int) -> ClipboardSection? {
        guard rows.indices.contains(row) else { return nil }
        switch rows[row] {
        case let .header(section), let .item(_, section): return section
        }
    }

    func row(of id: UUID) -> Int? {
        rows.firstIndex { $0.item?.id == id }
    }

    /// The rows that hold items, in order.
    var itemRows: [Int] {
        rows.indices.filter { rows[$0].item != nil }
    }

    func quickPasteNumber(forRow row: Int) -> Int? {
        quickPasteNumbers[row]
    }

    func item(quickPasteNumber number: Int) -> ClipboardItem? {
        quickPasteNumbers.first { $0.value == number }.flatMap { item(at: $0.key) }
    }

    /// Selected when the panel opens: the newest copy, which is what ⌘V would paste anyway, so ↓ reaches the one
    /// before it. The first item when there is no history.
    var initialRow: Int? {
        rows.firstIndex { row in
            if case .item(_, .history) = row {
                return true
            }
            return false
        } ?? itemRows.first
    }

    /// The item row at or after `row`, else the last one before it: what to select after deleting.
    func nearestItemRow(to row: Int) -> Int? {
        let items = itemRows
        return items.first { $0 >= row } ?? items.last
    }

    /// Where items dropped above `row` go: a section and the position in it (`ClipboardIndex.move`). Only meaningful
    /// while nothing is filtered, when the rows show the whole index.
    func dropDestination(aboveRow row: Int) -> (section: ClipboardSection, position: Int) {
        guard rows.indices.contains(row) else {
            if case .item(_, .pinned) = rows.last {
                return (.pinned, index.pinned.count)
            }
            return (.history, index.history.count)
        }
        switch rows[row] {
        case let .item(item, section):
            return (section, index.items(in: section).firstIndex { $0.id == item.id } ?? 0)
        case .header(.pinned):
            return (.pinned, 0)
        case .header(.history):
            return (.pinned, index.pinned.count)
        }
    }

    /// Whether `newPins` more items fit in the pins kept without Oriel Pro.
    func fitsFreePins(adding newPins: Int) -> Bool {
        index.pinned.count + newPins <= Self.freePins
    }

    /// The history the panel may show: all of it with Oriel Pro, else the free window.
    private var visibleHistory: [ClipboardItem] {
        guard !allows(.clipboardUnlimited) else { return index.history }
        let since = now().addingTimeInterval(-Double(Self.freeDays) * 86400)
        return Array(index.history.filter { $0.lastCopied >= since }.prefix(Self.freeCount))
    }

    private func rebuild() {
        let terms = ClipboardSearch.terms(in: query)
        let imageText = allows(.clipboardImageSearch)
        let shows = { (item: ClipboardItem) in
            self.filter.includes(item.kind) && ClipboardSearch.matches(item, terms: terms, includesImageText: imageText)
        }
        let pinned = index.pinned.filter(shows)
        let history = filter == .pinned ? [] : visibleHistory.filter(shows)
        var rows: [ClipboardRow] = []
        if !pinned.isEmpty {
            rows.append(.header(.pinned))
            rows += pinned.map { .item($0, .pinned) }
            if !history.isEmpty {
                rows.append(.header(.history))
            }
        }
        rows += history.map { .item($0, .history) }
        self.rows = rows
        quickPasteNumbers = [:]
        guard allows(.clipboardQuickPaste) else { return }
        for (number, row) in itemRows.prefix(9).enumerated() {
            quickPasteNumbers[row] = number + 1
        }
    }
}
