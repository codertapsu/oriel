import AppKit

/// The Activity Monitor window. Oriel's menu bar has no View or Process menu, so the window takes its own shortcuts
/// (⌘F, ⌘I, ⌥⌘Q, ⌘1–⌘5) before the main menu sees them.
final class ActivityWindow: NSWindow {
    /// Returns true when it handled the key.
    var onKeyEquivalent: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKeyEquivalent?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
