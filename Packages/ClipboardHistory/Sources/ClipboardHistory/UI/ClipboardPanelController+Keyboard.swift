import AppKit
import OrielCore

/// The keyboard. Typing goes to the search field while ↑ and ↓ move through the list; Return pastes, ⌥Return pastes
/// the other way (plain or formatted), ⌘1…⌘9 paste the first nine items, and the ⌘-shortcuts act on the selection.
extension ClipboardPanelController: NSSearchFieldDelegate {
    func controlTextDidChange(_: Notification) {
        searchChanged()
    }

    func searchChanged() {
        model.query = content.searchField.stringValue
        reload(selecting: [])
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)): moveCursor(by: -1, extending: false)
        case #selector(NSResponder.moveDown(_:)): moveCursor(by: 1, extending: false)
        case #selector(NSResponder.moveUpAndModifySelection(_:)): moveCursor(by: -1, extending: true)
        case #selector(NSResponder.moveDownAndModifySelection(_:)): moveCursor(by: 1, extending: true)
        case #selector(NSResponder.scrollPageUp(_:)), #selector(NSResponder.pageUp(_:)): moveCursor(by: -8, extending: false)
        case #selector(NSResponder.scrollPageDown(_:)), #selector(NSResponder.pageDown(_:)): moveCursor(by: 8, extending: false)
        case #selector(NSResponder.insertNewline(_:)): pasteSelection()
        case #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)): pasteSelection(inverted: true)
        case #selector(NSResponder.cancelOperation(_:)): escape()
        default: return false
        }
        return true
    }

    /// Keys the list does not use itself. Typing there goes on in the search field.
    func tableKeyDown(_ event: NSEvent) -> Bool {
        let flags = Self.modifiers(of: event)
        switch event.keyCode {
        case KeyCode.returnKey, Self.keypadEnter:
            pasteSelection(inverted: flags.contains(.option))
        case KeyCode.delete, KeyCode.forwardDelete:
            deleteSelection()
        case KeyCode.escape:
            escape()
        default:
            guard flags.isDisjoint(with: [.command, .control]), let characters = event.characters, !characters.isEmpty,
                  characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value < 0xF700 })
            else { return false }
            typeInSearch(characters)
        }
        return true
    }

    /// ⌘-shortcuts, from wherever the keyboard is in the panel.
    func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let flags = Self.modifiers(of: event)
        if flags == .command, let index = KeyCode.digits.firstIndex(of: event.keyCode) {
            if let item = model.item(quickPasteNumber: index + 1) {
                paste([item], plainText: pastesPlainTextByDefault)
            } else {
                NSSound.beep()
            }
            return true
        }
        if flags == [.command, .option], event.keyCode == KeyCode.upArrow || event.keyCode == KeyCode.downArrow {
            moveSelection(by: event.keyCode == KeyCode.upArrow ? -1 : 1)
            return true
        }
        guard flags == .command else { return false }
        switch event.keyCode {
        case KeyCode.delete, KeyCode.forwardDelete:
            deleteSelection()
        case KeyCode.returnKey:
            copy(selectedItems)
        default:
            return handleCommandCharacter(event.charactersIgnoringModifiers?.lowercased() ?? "")
        }
        return true
    }

    private func handleCommandCharacter(_ character: String) -> Bool {
        switch character {
        case "p":
            togglePinSelection()
        case "c":
            // Copying text selected in the search field or the preview comes first.
            guard !hasTextSelection else { return false }
            copy(selectedItems)
        case "z":
            guard !deletions.isEmpty else { return false }
            undoDeletion()
        case "a":
            guard panel.firstResponder === content.table else { return false }
            content.table.selectRowIndexes(IndexSet(model.itemRows), byExtendingSelection: false)
        case "f":
            panel.makeFirstResponder(content.searchField)
        case ",":
            showSettings()
        case "w":
            close()
        default:
            return false
        }
        return true
    }

    /// Moves the keyboard selection through the item rows; with ⇧ it grows or shrinks a range from where it began.
    func moveCursor(by step: Int, extending: Bool) {
        let rows = model.itemRows
        guard !rows.isEmpty else { return }
        let selected = content.table.selectedRowIndexes
        let current = cursorRow ?? (step > 0 ? selected.last : selected.first)
        let position = current.flatMap { rows.firstIndex(of: $0) } ?? (step > 0 ? -1 : rows.count)
        let next = rows[max(0, min(rows.count - 1, position + step))]
        isMovingCursor = true
        defer { isMovingCursor = false }
        if extending {
            let anchor = anchorRow ?? current ?? next
            let range = min(anchor, next) ... max(anchor, next)
            content.table.selectRowIndexes(IndexSet(rows.filter { range.contains($0) }), byExtendingSelection: false)
            anchorRow = anchor
        } else {
            content.table.selectRowIndexes([next], byExtendingSelection: false)
            anchorRow = next
        }
        cursorRow = next
        content.table.scrollRowToVisible(next)
    }

    private static let keypadEnter: UInt16 = 76

    private static func modifiers(of event: NSEvent) -> NSEvent.ModifierFlags {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
    }

    private var hasTextSelection: Bool {
        guard let editor = panel.firstResponder as? NSTextView else { return false }
        return editor.selectedRange().length > 0
    }

    private func typeInSearch(_ characters: String) {
        panel.makeFirstResponder(content.searchField)
        guard let editor = content.searchField.currentEditor() as? NSTextView else { return }
        let end = (editor.string as NSString).length
        editor.setSelectedRange(NSRange(location: end, length: 0))
        editor.insertText(characters, replacementRange: NSRange(location: end, length: 0))
    }
}
