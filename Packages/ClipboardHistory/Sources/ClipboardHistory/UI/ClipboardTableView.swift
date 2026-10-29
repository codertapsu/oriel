import AppKit

/// The list. Keys the table does not use itself (Return, Delete, Esc, typing) go to `onKeyDown` first.
final class ClipboardTableView: NSTableView {
    /// Returns true when it handled the key.
    var onKeyDown: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }

    /// The panel does not become key until something in it is clicked, and the first click should already select.
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }
}
