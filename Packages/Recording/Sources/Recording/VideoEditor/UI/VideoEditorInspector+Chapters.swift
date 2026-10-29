import AppKit

/// The inspector's chapter list: times and editable titles, add and remove, and the YouTube timestamps.
extension VideoEditorInspector: NSTableViewDataSource, NSTableViewDelegate {
    private static let timeColumn = NSUserInterfaceItemIdentifier("time")
    private static let titleColumn = NSUserInterfaceItemIdentifier("title")

    func chapterSection() -> [NSView] {
        let time = NSTableColumn(identifier: Self.timeColumn)
        time.title = "Time"
        time.width = 64
        time.minWidth = 56
        let title = NSTableColumn(identifier: Self.titleColumn)
        title.title = "Title"
        title.resizingMask = .autoresizingMask
        chapterTable.addTableColumn(time)
        chapterTable.addTableColumn(title)
        chapterTable.dataSource = self
        chapterTable.delegate = self
        chapterTable.style = .inset
        chapterTable.rowHeight = 22
        chapterTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        chapterTable.setAccessibilityLabel("Chapters")
        let scroll = NSScrollView()
        scroll.documentView = chapterTable
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.heightAnchor.constraint(equalToConstant: 150).isActive = true

        addChapterButton.title = "Add Chapter"
        configure(addChapterButton, symbol: "bookmark", action: #selector(addChapter(_:)))
        addChapterButton.toolTip = "Add a chapter at the playhead (M)"
        removeChapterButton.title = "Delete"
        configure(removeChapterButton, symbol: "trash", action: #selector(removeChapter(_:)))
        removeChapterButton.toolTip = "Delete the selected chapter (Delete)"
        removeChapterButton.setAccessibilityLabel("Delete Chapter")
        let edit = NSStackView(views: [addChapterButton, removeChapterButton])
        edit.spacing = 8

        configure(copyTimestampsButton, symbol: "doc.on.doc", action: #selector(copyTimestamps(_:)))
        copyTimestampsButton.toolTip = "Copy the chapters as timestamps for a video description"
        configure(saveTimestampsButton, symbol: "square.and.arrow.down", action: #selector(saveTimestamps(_:)))
        saveTimestampsButton.toolTip = "Save the chapters as timestamps in a text file"
        let share = NSStackView(views: [copyTimestampsButton, saveTimestampsButton])
        share.spacing = 8
        Self.style(note: chapterNote)
        return [Self.heading("Chapters"), scroll, edit, share, chapterNote]
    }

    /// Reloads the list, keeping the selection in step with the timeline's.
    func updateChapters() {
        chapterTable.reloadData()
        let chapters = session.edit.chapters
        if case let .chapter(id) = session.selection, let row = chapters.firstIndex(where: { $0.id == id }) {
            chapterTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            chapterTable.scrollRowToVisible(row)
        } else {
            chapterTable.deselectAll(nil)
        }
        removeChapterButton.isEnabled = session.selectedChapter != nil
        let exported = ChapterList.build(chapters, range: session.range)
        copyTimestampsButton.isEnabled = !exported.isEmpty
        saveTimestampsButton.isEnabled = !exported.isEmpty
        if chapters.isEmpty {
            chapterNote.stringValue = "Press M to add a chapter at the playhead. Exported movies keep their chapters "
                + "for QuickTime Player and IINA, and they can be copied as YouTube timestamps."
        } else if let problem = ChapterTimestamps.youTubeProblems(exported).first {
            chapterNote.stringValue = "The exported movie keeps \(exported.count) chapter\(exported.count == 1 ? "" : "s"). \(problem)"
        } else {
            chapterNote.stringValue = "The exported movie keeps \(exported.count) chapters, ready for YouTube."
        }
    }

    /// Starts editing a chapter's title, after a double-click on its marker.
    func beginRenaming(_ id: UUID) {
        guard let row = session.edit.chapters.firstIndex(where: { $0.id == id }) else { return }
        chapterTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        chapterTable.scrollRowToVisible(row)
        chapterTable.editColumn(1, row: row, with: nil, select: true)
    }

    @objc private func addChapter(_: Any?) {
        session.addChapter(at: currentTime())
    }

    @objc private func removeChapter(_: Any?) {
        guard session.selectedChapter != nil else { return }
        session.deleteSelection()
    }

    @objc private func titleEdited(_ sender: NSTextField) {
        let row = chapterTable.row(for: sender)
        let chapters = session.edit.chapters
        guard chapters.indices.contains(row), chapters[row].title != sender.stringValue else { return }
        session.renameChapter(chapters[row].id, to: sender.stringValue)
    }

    // MARK: NSTableViewDataSource, NSTableViewDelegate

    func numberOfRows(in _: NSTableView) -> Int {
        session.edit.chapters.count
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let chapters = session.edit.chapters
        guard chapters.indices.contains(row), let column else { return nil }
        let marker = chapters[row]
        let identifier = column.identifier
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? makeCell(identifier)
        if identifier == Self.timeColumn {
            cell.textField?.stringValue = Timecode.string(marker.time)
            cell.textField?.setAccessibilityLabel("Time")
        } else {
            cell.textField?.stringValue = marker.title
            cell.textField?.placeholderString = "Chapter \(row + 1)"
            cell.textField?.setAccessibilityLabel("Title")
        }
        return cell
    }

    func tableViewSelectionDidChange(_: Notification) {
        let row = chapterTable.selectedRow
        let chapters = session.edit.chapters
        guard chapters.indices.contains(row) else {
            if session.selectedChapter != nil {
                session.select(nil)
            }
            return
        }
        let marker = chapters[row]
        guard session.selection != .chapter(marker.id) else { return }
        session.select(.chapter(marker.id))
        onSeek?(marker.time)
    }

    private func makeCell(_ identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let field = NSTextField(labelWithString: "")
        field.lineBreakMode = .byTruncatingTail
        if identifier == Self.timeColumn {
            field.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            field.textColor = .secondaryLabelColor
        } else {
            field.isEditable = true
            field.target = self
            field.action = #selector(titleEdited(_:))
        }
        field.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(field)
        cell.textField = field
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
