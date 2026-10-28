import AppKit

/// The editor's window. Oriel is a menu-bar app and may have no main menu, so the window delivers the editor's
/// ⌘-shortcuts itself, and the standard editing ones to the label being typed.
final class EditorWindow: NSWindow {
    /// Runs an editor command; returns whether it was handled.
    var commandHandler: ((EditorCommand) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        if let textView = firstResponder as? NSTextView, Self.performTextEditingShortcut(event, in: textView) {
            return true
        }
        if let command = EditorShortcuts.command(for: event), commandHandler?(command) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Keys no responder took (the focus is on a toolbar control, say) still pick tools.
    override func keyDown(with event: NSEvent) {
        if let command = EditorShortcuts.command(for: event), commandHandler?(command) == true {
            return
        }
        super.keyDown(with: event)
    }

    /// ⌘Z, ⇧⌘Z, ⌘X, ⌘C, ⌘V and ⌘A act on the text being typed; anything else (⌘S, ⌘E, ⌘W) goes to the editor.
    private static func performTextEditingShortcut(_ event: NSEvent, in textView: NSTextView) -> Bool {
        let shift = event.modifierFlags.contains(.shift)
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "z":
            if shift {
                textView.undoManager?.redo()
            } else {
                textView.undoManager?.undo()
            }
        case "x" where !shift:
            textView.cut(nil)
        case "c" where !shift:
            textView.copy(nil)
        case "v" where !shift:
            textView.paste(nil)
        case "a" where !shift:
            textView.selectAll(nil)
        default:
            return false
        }
        return true
    }
}
