import AppKit
import SharedUI

/// The context menu of the list and the panel's ⋯ menu, built each time they open from the current selection.
extension ClipboardPanelController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === tableMenu {
            buildContextMenu(menu)
        } else {
            buildMoreMenu(menu)
        }
    }

    private func buildContextMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = content.table.clickedRow
        // A right-click outside the selection acts on the row clicked, as in Finder.
        if row >= 0, !content.table.selectedRowIndexes.contains(row), model.item(at: row) != nil {
            content.table.selectRowIndexes([row], byExtendingSelection: false)
        }
        let items = selectedItems
        guard !items.isEmpty else { return }
        let textual = items.contains { $0.kind.isTextual }
        menu.addItem(item(content.pasteButton.title, "doc.on.clipboard", key: "\r", modifiers: []) { [weak self] in
            self?.pasteSelection()
        })
        if textual {
            let plain = pastesPlainTextByDefault ? "Paste with Formatting" : "Paste as Plain Text"
            menu.addItem(item(plain, "textformat", key: "\r", modifiers: [.option]) { [weak self] in self?.pasteSelection(inverted: true) })
        }
        menu.addItem(item("Copy", "doc.on.doc", key: "c") { [weak self] in self?.copy(self?.selectedItems ?? []) })
        menu.addItem(.separator())
        let pinned = Set(model.index.pinned.map(\.id))
        let allPinned = items.allSatisfy { pinned.contains($0.id) }
        menu.addItem(item(allPinned ? "Unpin" : "Pin", allPinned ? "pin.slash" : "pin", key: "p") { [weak self] in
            self?.togglePinSelection()
        })
        if !model.isFiltering {
            menu.addItem(item("Move to Top", "arrow.up.to.line") { [weak self] in self?.moveToTop(self?.selectedItems ?? []) })
        }
        addItemSpecificActions(to: menu, for: items)
        menu.addItem(.separator())
        let delete = items.count > 1 ? "Delete \(items.count) Items" : "Delete"
        menu.addItem(item(delete, "trash", key: "\u{8}") { [weak self] in self?.deleteSelection() })
    }

    private func addItemSpecificActions(to menu: NSMenu, for items: [ClipboardItem]) {
        guard items.count == 1, let selected = items.first else { return }
        switch selected.kind {
        case .link:
            let address = (selected.text ?? selected.title).trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: address).flatMap({ $0.scheme == nil ? URL(string: "https://" + address) : $0 }) {
                menu.addItem(item("Open Link", "safari") { [weak self] in self?.open(url) })
            }
        case .files:
            menu.addItem(item("Show in Finder", "folder") { [weak self] in self?.reveal(selected.fileURLs ?? []) })
        case .image:
            if let text = selected.recognizedText, !text.isEmpty {
                menu.addItem(item("Copy Text in Image", "text.viewfinder") { [weak self] in self?.copyRecognizedText(of: selected) })
            }
        case .text, .richText, .color, .other:
            break
        }
    }

    private func buildMoreMenu(_ menu: NSMenu) {
        // The first item of a pull-down menu is its button's face.
        while menu.items.count > 1 {
            menu.removeItem(at: 1)
        }
        let paused = recorder.isPaused
        let pause = paused ? "Resume Clipboard History" : "Pause Clipboard History"
        menu.addItem(item(pause, paused ? "play.circle" : "pause.circle") { [weak self] in self?.togglePause() })
        menu.addItem(item("Clear History", "clear") { [weak self] in self?.clearHistory() })
        menu.addItem(.separator())
        menu.addItem(item("Clipboard History Settings…", "gearshape", key: ",") { [weak self] in self?.showSettings() })
    }

    /// Key equivalents here only label the menu; the panel handles the keys themselves.
    private func item(
        _ title: String,
        _ symbol: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        action: @escaping @MainActor @Sendable () -> Void
    ) -> NSMenuItem {
        ActionMenuItem(title, symbol: symbol, key: key, modifiers: modifiers, handler: action)
    }
}
