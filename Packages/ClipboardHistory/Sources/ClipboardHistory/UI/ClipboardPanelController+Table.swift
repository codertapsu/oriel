import AppKit
import SharedUI

/// The list: rows, selection, and drag and drop, both to reorder (and pin, by dropping into Pinned) and to drop an
/// item into another app.
extension ClipboardPanelController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in _: NSTableView) -> Int {
        model.rows.count
    }

    func tableView(_: NSTableView, isGroupRow row: Int) -> Bool {
        model.item(at: row) == nil
    }

    func tableView(_: NSTableView, heightOfRow row: Int) -> CGFloat {
        model.item(at: row) == nil ? ClipboardHeaderView.height : ClipboardRowView.height
    }

    func tableView(_: NSTableView, shouldSelectRow row: Int) -> Bool {
        model.item(at: row) != nil
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        switch model.rows[row] {
        case let .header(section):
            let view = tableView.makeView(withIdentifier: ClipboardHeaderView.identifier, owner: nil) as? ClipboardHeaderView
                ?? ClipboardHeaderView(frame: .zero)
            view.configure(section)
            return view
        case let .item(item, section):
            let view = tableView.makeView(withIdentifier: ClipboardRowView.identifier, owner: nil) as? ClipboardRowView
                ?? ClipboardRowView(frame: .zero)
            let image = item.kind == .files ? item.fileURLs?.first.map(icons.fileIcon) : thumbnail(for: item)
            view.configure(
                item,
                isPinned: section == .pinned,
                number: model.quickPasteNumber(forRow: row),
                appIcon: icons.appIcon(bundleID: item.sourceBundleID),
                image: image,
                now: Date()
            )
            return view
        }
    }

    func tableViewSelectionDidChange(_: Notification) {
        if !isMovingCursor {
            cursorRow = nil
            anchorRow = nil
        }
        updateChrome()
        updatePreview()
    }

    // MARK: Drag and drop

    /// Each dragged row carries its id, for reordering, and its contents, so it can be dropped into another app.
    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        guard let item = model.item(at: row) else { return nil }
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.id.uuidString, forType: Self.rowType)
        let content = recorder.store.content(of: item.id)
        let entry = content.map { PasteComposer.Entry(item: item, content: $0) }
        for representation in entry.flatMap({ PasteComposer.compose([$0], plainText: false) })?.items.first ?? [] {
            pasteboardItem.setData(representation.data, forType: NSPasteboard.PasteboardType(representation.type))
        }
        return pasteboardItem
    }

    /// Reordering only while nothing is filtered: with rows hidden, "above this row" has no clear place.
    func tableView(
        _ tableView: NSTableView,
        validateDrop info: any NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation operation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard (info.draggingSource as? NSTableView) === tableView, !model.isFiltering else { return [] }
        if operation == .on {
            tableView.setDropRow(row, dropOperation: .above)
        }
        return .move
    }

    func tableView(_: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int, dropOperation _: NSTableView.DropOperation) -> Bool {
        let ids = (info.draggingPasteboard.pasteboardItems ?? []).compactMap { $0.string(forType: Self.rowType).flatMap(UUID.init) }
        guard !ids.isEmpty else { return false }
        let destination = model.dropDestination(aboveRow: row)
        move(ids, to: destination.section, at: destination.position)
        return true
    }
}
