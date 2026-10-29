import AppKit
import OrielCore
import SharedUI

/// Pasting, copying, deleting with Undo, pinning, reordering and the rest of what the panel does to items.
extension ClipboardPanelController {
    var pastesPlainTextByDefault: Bool {
        settings[ClipboardSettings.pastesPlainText]
    }

    /// Return pastes as the setting says; ⌥Return (`inverted`) the other way.
    func pasteSelection(inverted: Bool = false) {
        paste(selectedItems, plainText: pastesPlainTextByDefault != inverted)
    }

    /// Puts the items on the clipboard, closes the panel and posts ⌘V to the app that was in front, whose focused
    /// field takes the paste. Without Accessibility macOS drops posted keys, so the items are only copied.
    func paste(_ items: [ClipboardItem], plainText: Bool) {
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        let target = target
        let store = recorder.store
        Task {
            guard await put(items, plainText: plainText, from: store) else { return }
            close()
            finish(items, pasted: true)
            guard permissions.status(of: .accessibility) == .granted else {
                Toast.show("Copied. Press ⌘V to paste.", symbol: "doc.on.clipboard")
                return
            }
            if let target, target != NSRunningApplication.current, !target.isActive {
                target.activate()
            }
            // Gives the app a moment to take the keyboard back from the panel.
            try? await Task.sleep(for: .milliseconds(80))
            PasteSimulator.postCommandV()
        }
    }

    func copy(_ items: [ClipboardItem], plainText: Bool = false) {
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        let store = recorder.store
        Task {
            guard await put(items, plainText: plainText, from: store) else { return }
            close()
            finish(items, pasted: false)
            Toast.show(items.count == 1 ? "Copied" : "Copied \(items.count) items", symbol: "doc.on.doc")
        }
    }

    func deleteSelection() {
        let items = selectedItems
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        let row = content.table.selectedRowIndexes.first ?? 0
        let store = recorder.store
        Task {
            guard let deletion = try? await store.remove(Set(items.map(\.id))), !deletion.isEmpty else { return }
            deletions.append(deletion)
            await changed(selecting: [], fallbackRow: row)
            content.showUndo("Deleted \(ClipboardFormat.count(deletion.count, "item"))")
        }
    }

    func undoDeletion() {
        guard let deletion = deletions.popLast() else {
            NSSound.beep()
            return
        }
        let store = recorder.store
        Task {
            try? await store.restore(deletion)
            content.showUndo(nil)
            await changed(selecting: deletion.removals.map(\.item.id))
            // An earlier deletion can still be taken back.
            if let earlier = deletions.last {
                content.showUndo("Deleted \(ClipboardFormat.count(earlier.count, "item"))")
            }
        }
    }

    /// Clears the history; pinned items stay. Undo brings it back until the panel closes.
    func clearHistory() {
        let store = recorder.store
        Task {
            guard let deletion = try? await store.removeAll(includingPinned: false), !deletion.isEmpty else { return }
            deletions.append(deletion)
            await changed(selecting: [])
            content.showUndo("Cleared \(ClipboardFormat.count(deletion.count, "item"))")
        }
    }

    /// Pins the selection, or unpins it when every selected item is pinned.
    func togglePinSelection() {
        let items = selectedItems
        guard !items.isEmpty else {
            NSSound.beep()
            return
        }
        let pinned = Set(model.index.pinned.map(\.id))
        let pins = !items.allSatisfy { pinned.contains($0.id) }
        let store = recorder.store
        Task {
            try? await store.setPinned(items.map(\.id), pins)
            await changed(selecting: items.map(\.id))
        }
    }

    /// ⌥⌘↑ and ⌥⌘↓: moves the selected items one place within their section.
    func moveSelection(by offset: Int) {
        let items = selectedItems
        let positions = items.compactMap { model.index.position(of: $0.id) }
        guard !model.isFiltering, let section = positions.first?.section, positions.allSatisfy({ $0.section == section }),
              let low = positions.map(\.index).min(), let high = positions.map(\.index).max()
        else {
            NSSound.beep()
            return
        }
        let count = model.index.items(in: section).count
        move(items.map(\.id), to: section, at: offset < 0 ? max(low - 1, 0) : min(high + 2, count))
    }

    func moveToTop(_ items: [ClipboardItem]) {
        let pinned = Set(model.index.pinned.map(\.id))
        move(items.map(\.id), to: items.allSatisfy { pinned.contains($0.id) } ? .pinned : .history, at: 0)
    }

    func move(_ ids: [UUID], to section: ClipboardSection, at position: Int) {
        let store = recorder.store
        Task {
            try? await store.move(ids, to: section, at: position)
            await changed(selecting: ids)
        }
    }

    func copyRecognizedText(of item: ClipboardItem) {
        guard let text = item.recognizedText, !text.isEmpty else { return }
        close()
        // A new copy, announced like any other, so the text joins the history.
        if Pasteboard.copy(text) {
            Toast.show("Copied the text", symbol: "text.viewfinder")
        }
    }

    func open(_ url: URL) {
        close()
        NSWorkspace.shared.open(url)
    }

    func reveal(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        close()
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func togglePause() {
        recorder.setPaused(!recorder.isPaused)
        updateChrome()
    }

    func showSettings() {
        close()
        openSettings?()
    }

    /// Esc clears the search first, then closes.
    func escape() {
        if content.searchField.stringValue.isEmpty {
            close()
        } else {
            content.searchField.stringValue = ""
            searchChanged()
        }
    }

    // MARK: Steps

    /// Writes the items to the clipboard without announcing them, since the history has them already. Their contents
    /// are read and decrypted off the main thread.
    private func put(_ items: [ClipboardItem], plainText: Bool, from store: ClipboardStore) async -> Bool {
        let entries = await Task.detached(priority: .userInitiated) {
            items.compactMap { item in store.content(of: item.id).map { PasteComposer.Entry(item: item, content: $0) } }
        }.value
        guard let snapshot = PasteComposer.compose(entries, plainText: plainText), Pasteboard.write(snapshot, announces: false) else {
            NSSound.beep()
            return false
        }
        return true
    }

    /// After a paste or copy the item is on the clipboard again, so it moves to the top; after a paste with "Remove
    /// items after pasting" on, it leaves the history instead. Pinned items always stay.
    private func finish(_ items: [ClipboardItem], pasted: Bool) {
        let store = recorder.store
        let pinned = Set(model.index.pinned.map(\.id))
        let removes = pasted && settings[ClipboardSettings.removesAfterPaste]
        Task {
            if removes {
                try? await store.delete(Set(items.map(\.id)).subtracting(pinned))
            } else if items.count == 1, let item = items.first {
                try? await store.touch(item.id, at: Date())
            }
            onHistoryChanged?()
        }
    }

    private func changed(selecting ids: [UUID], fallbackRow: Int? = nil) async {
        await model.update(recorder.store.index())
        reload(selecting: ids, fallbackRow: fallbackRow)
        onHistoryChanged?()
    }

    // MARK: Buttons

    @objc func pinClicked() {
        togglePinSelection()
    }

    @objc func deleteClicked() {
        deleteSelection()
    }

    @objc func undoClicked() {
        undoDeletion()
    }

    @objc func copyClicked() {
        copy(selectedItems)
    }

    @objc func pasteClicked() {
        pasteSelection()
    }

    @objc func doubleClicked() {
        let row = content.table.clickedRow
        guard let item = model.item(at: row) else { return }
        paste([item], plainText: pastesPlainTextByDefault)
    }

    @objc func filterChanged() {
        model.filter = ClipboardFilter.allCases[max(content.filterButton.indexOfSelectedItem, 0)]
        reload(selecting: [])
    }
}
