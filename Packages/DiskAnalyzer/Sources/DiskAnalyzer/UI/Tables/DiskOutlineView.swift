import AppKit

/// An outline with the analyzer's keys: Return opens, Space shows Quick Look; and a context menu for the rows
/// right-clicked, which are selected first, as in Finder.
final class DiskOutlineView: NSOutlineView {
    var onReturn: (() -> Void)?
    var onSpace: (() -> Void)?
    var menuProvider: (() -> NSMenu?)?
    /// Shows and hides columns from the header.
    private lazy var columnMenu = ColumnMenu(table: self)

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        headerView?.menu = columnMenu.menu
    }

    override func keyDown(with event: NSEvent) {
        switch event.specialKey {
        case .carriageReturn?, .enter?:
            onReturn?()
        default:
            if event.charactersIgnoringModifiers == " ", event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask) {
                onSpace?()
            } else {
                super.keyDown(with: event)
            }
        }
    }

    /// Columns wider than the pane are shrunk to fit it, once laid out, so none runs off the edge.
    override func layout() {
        super.layout()
        ColumnFitting.fit(self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let row = row(at: convert(event.locationInWindow, from: nil))
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes([row], byExtendingSelection: false)
        }
        return menuProvider?()
    }
}
