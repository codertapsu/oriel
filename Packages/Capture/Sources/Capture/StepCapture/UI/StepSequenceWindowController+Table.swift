import AppKit

/// The list of steps: one row per step, dragged to reorder, and an image dropped on a row replaces that step's image.
extension StepSequenceWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func configureTable() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("step"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .inset
        table.rowHeight = StepRowView.height
        table.allowsMultipleSelection = true
        table.usesAutomaticRowHeights = false
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.dataSource = self
        table.delegate = self
        table.registerForDraggedTypes([Self.rowType, .png, .tiff, .fileURL])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.setDraggingSourceOperationMask([], forLocal: false)
        table.draggingDestinationFeedbackStyle = .gap
        table.onDelete = { [weak self] in self?.deleteSelectedSteps() }
        table.menu = makeContextMenu()
        table.setAccessibilityLabel("Steps")
    }

    func numberOfRows(in _: NSTableView) -> Int {
        stepDocument.sequence.count
    }

    func tableView(_ tableView: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        guard stepDocument.sequence.steps.indices.contains(row) else { return nil }
        let step = stepDocument.sequence.steps[row]
        let view = tableView.makeView(withIdentifier: StepRowView.identifier, owner: self) as? StepRowView ?? StepRowView()
        view.configure(step: step, number: row + 1, thumbnail: stepDocument.thumbnail(of: step), canAnnotate: canAnnotate)
        let id = step.id
        view.onTitleChange = { [weak self] title in self?.stepDocument.setTitle(title, of: id) }
        view.onNoteChange = { [weak self] note in self?.stepDocument.setNote(note, of: id) }
        view.onRetake = { [weak self] in self?.retake(id) }
        view.onAnnotate = { [weak self] in self?.annotate(id) }
        view.onDelete = { [weak self] in self?.deleteSteps([id]) }
        return view
    }

    func tableView(_: NSTableView, heightOfRow _: Int) -> CGFloat {
        StepRowView.height
    }

    // MARK: - Dragging

    func tableView(_: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        guard stepDocument.sequence.steps.indices.contains(row) else { return nil }
        let item = NSPasteboardItem()
        item.setString(stepDocument.sequence.steps[row].id.uuidString, forType: Self.rowType)
        return item
    }

    func tableView(
        _ tableView: NSTableView,
        validateDrop info: any NSDraggingInfo,
        proposedRow row: Int,
        proposedDropOperation operation: NSTableView.DropOperation
    ) -> NSDragOperation {
        let pasteboard = info.draggingPasteboard
        if pasteboard.types?.contains(Self.rowType) == true {
            guard info.draggingSource as? NSTableView === tableView else { return [] }
            if operation == .on {
                tableView.setDropRow(row, dropOperation: .above)
            }
            return .move
        }
        guard StepImageReader.canRead(pasteboard), !stepDocument.sequence.isEmpty else { return [] }
        tableView.setDropRow(min(max(row, 0), stepDocument.sequence.count - 1), dropOperation: .on)
        return .copy
    }

    func tableView(
        _: NSTableView,
        acceptDrop info: any NSDraggingInfo,
        row: Int,
        dropOperation _: NSTableView.DropOperation
    ) -> Bool {
        let pasteboard = info.draggingPasteboard
        if pasteboard.types?.contains(Self.rowType) == true {
            let ids = Set((pasteboard.pasteboardItems ?? [])
                .compactMap { $0.string(forType: Self.rowType).flatMap(UUID.init(uuidString:)) })
            let offsets = IndexSet(stepDocument.sequence.steps.enumerated().filter { ids.contains($0.element.id) }.map(\.offset))
            guard !offsets.isEmpty else { return false }
            edit(offsets.count == 1 ? "Move Step" : "Move Steps") { stepDocument.move(fromOffsets: offsets, toOffset: row) }
            return true
        }
        guard stepDocument.sequence.steps.indices.contains(row), let dropped = StepImageReader.image(from: pasteboard) else { return false }
        replaceImage(of: stepDocument.sequence.steps[row].id, with: dropped.image, scale: dropped.scale)
        return true
    }
}
