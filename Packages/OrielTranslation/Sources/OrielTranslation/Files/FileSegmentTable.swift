import AppKit

/// The file window's two columns, original and translation, one row per paragraph, cue or block, with a heading row
/// for each page of a PDF. Row heights are measured, cached and measured again when the columns change width.
/// ⌘C and the context menu copy the selected rows' translations or originals.
@MainActor
final class FileSegmentTable: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    enum Row: Equatable {
        case page(Int)
        case segment(DocumentSegment)
    }

    let scrollView = NSScrollView()
    private let tableView = SegmentTableView()
    private let originalColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("original"))
    private let translationColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("translation"))
    private var rows: [Row] = []
    private var translations: [Int: String] = [:]
    private var isFinished = false
    private var heights: [Int: CGFloat] = [:]
    private var measuredWidths = (original: CGFloat(0), translation: CGFloat(0))
    var onCopy: (@MainActor (String) -> Void)?

    /// Where keyboard focus starts, so ↑↓, ⌘A and ⌘C work at once.
    var focusView: NSView {
        tableView
    }

    override init() {
        super.init()
        originalColumn.title = "Original"
        translationColumn.title = "Translation"
        for column in [originalColumn, translationColumn] {
            column.resizingMask = [.autoresizingMask, .userResizingMask]
            column.minWidth = 160
            tableView.addTableColumn(column)
        }
        tableView.style = .inset
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.allowsMultipleSelection = true
        tableView.gridStyleMask = .solidHorizontalGridLineMask
        tableView.intercellSpacing = CGSize(width: 10, height: 0)
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.menu = contextMenu()
        tableView.copyHandler = { [weak self] in self?.copySelection(.translation) }
        tableView.setAccessibilityLabel("Original and translation")
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        NotificationCenter.default.addObserver(
            self, selector: #selector(columnsResized), name: NSTableView.columnDidResizeNotification, object: tableView
        )
    }

    /// Shows the segments; the translation column is titled with the target language.
    func update(segments: [DocumentSegment], translations: [Int: String], target: String, isFinished: Bool) {
        translationColumn.title = "Translation (\(target))"
        let newRows = Self.rows(for: segments)
        let changed = newRows != rows || translations != self.translations || isFinished != self.isFinished
        guard changed else { return }
        if newRows != rows {
            heights = [:]
        } else {
            for (id, text) in translations where self.translations[id] != text {
                heights[id] = nil
            }
        }
        rows = newRows
        self.translations = translations
        self.isFinished = isFinished
        tableView.reloadData()
    }

    /// Segment rows, with a page heading before each page when a PDF has more than one.
    static func rows(for segments: [DocumentSegment]) -> [Row] {
        let pages = Set(segments.compactMap(\.page))
        var rows: [Row] = []
        var page: Int?
        for segment in segments {
            if pages.count > 1, let segmentPage = segment.page, segmentPage != page {
                page = segmentPage
                rows.append(.page(segmentPage))
            }
            rows.append(.segment(segment))
        }
        return rows
    }

    // MARK: - Data source and delegate

    func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    func tableView(_: NSTableView, isGroupRow row: Int) -> Bool {
        if case .page = rows[row] {
            return true
        }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch rows[row] {
        case let .page(number):
            let label = NSTextField(labelWithString: "Page \(number)")
            label.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
            label.textColor = .secondaryLabelColor
            return label
        case let .segment(segment):
            let identifier = NSUserInterfaceItemIdentifier("segment")
            let cell = tableView.makeView(withIdentifier: identifier, owner: nil) as? FileSegmentCellView ?? {
                let cell = FileSegmentCellView()
                cell.identifier = identifier
                return cell
            }()
            let caption = Self.caption(for: segment)
            let shown = presentation(of: segment)
            if tableColumn === originalColumn {
                cell.show(text: shown.original, font: shown.font, color: shown.originalColor, caption: caption, captionSpace: false)
            } else {
                cell.show(
                    text: shown.translation,
                    font: shown.font,
                    color: shown.translationColor,
                    caption: nil,
                    captionSpace: caption != nil
                )
            }
            return cell
        }
    }

    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard case let .segment(segment) = rows[row] else { return 26 }
        if let height = heights[segment.id] {
            return height
        }
        let shown = presentation(of: segment)
        let original = FileSegmentCellView.textHeight(shown.original, font: shown.font, width: originalColumn.width)
        let translated = FileSegmentCellView.textHeight(shown.translation, font: shown.font, width: translationColumn.width)
        let caption = Self.caption(for: segment) == nil ? 0 : FileSegmentCellView.captionHeight + FileSegmentCellView.captionSpacing
        let insets = FileSegmentCellView.insets
        let height = max(22, max(original, translated) + caption + insets.top + insets.bottom)
        heights[segment.id] = height
        return height
    }

    func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        if case .segment = rows[row] {
            return true
        }
        return false
    }

    private func presentation(of segment: DocumentSegment) -> SegmentPresentation {
        SegmentPresentation(segment, translation: translations[segment.id], isFinished: isFinished)
    }

    /// A cue's timing; nil for everything else.
    static func caption(for segment: DocumentSegment) -> String? {
        guard let cue = segment.cue else { return nil }
        return "\(SubtitleFile.timestamp(cue.start, separator: ",")) → \(SubtitleFile.timestamp(cue.end, separator: ","))"
    }

    @objc private func columnsResized() {
        let widths = (originalColumn.width, translationColumn.width)
        guard widths != measuredWidths else { return }
        measuredWidths = widths
        heights = [:]
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0 ..< rows.count))
    }

    // MARK: - Copying

    private enum Side {
        case translation, original
    }

    private func contextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy Translation", action: #selector(copyTranslations), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Copy Original", action: #selector(copyOriginals), keyEquivalent: "").target = self
        return menu
    }

    @objc private func copyTranslations() {
        copySelection(.translation)
    }

    @objc private func copyOriginals() {
        copySelection(.original)
    }

    /// The clicked row, or the selection when the click was on a selected row.
    private func targetRows() -> IndexSet {
        let clicked = tableView.clickedRow
        if clicked >= 0, !tableView.selectedRowIndexes.contains(clicked) {
            return IndexSet(integer: clicked)
        }
        return tableView.selectedRowIndexes
    }

    private func copySelection(_ side: Side) {
        let texts = targetRows().compactMap { index -> String? in
            guard rows.indices.contains(index), case let .segment(segment) = rows[index] else { return nil }
            let text = switch side {
            case .translation: segment.verbatim ?? translations[segment.id] ?? ""
            case .original: segment.original
            }
            return text.isEmpty ? nil : text
        }
        guard !texts.isEmpty else { return }
        onCopy?(texts.joined(separator: "\n\n"))
    }
}

/// Hands ⌘C (Edit → Copy) to the table's owner.
@MainActor
private final class SegmentTableView: NSTableView {
    var copyHandler: (@MainActor () -> Void)?

    @objc func copy(_: Any?) {
        copyHandler?()
    }
}
