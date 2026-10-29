import AppKit

/// The list. Return opens the details, and Edit → Copy (⌘C) copies the selected processes; keys it does not use go
/// to `onKeyDown` first.
final class ProcessOutlineView: NSOutlineView, NSMenuItemValidation {
    /// Returns true when it handled the key.
    var onKeyDown: ((NSEvent) -> Bool)?
    var onCopy: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }

    @objc func copy(_: Any?) {
        onCopy?()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(copy(_:)) {
            return !selectedRowIndexes.isEmpty
        }
        return true
    }

    /// A right-click on a row outside the selection acts on that row, as in Finder.
    override func menu(for event: NSEvent) -> NSMenu? {
        let row = row(at: convert(event.locationInWindow, from: nil))
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes([row], byExtendingSelection: false)
        }
        return super.menu(for: event)
    }
}
