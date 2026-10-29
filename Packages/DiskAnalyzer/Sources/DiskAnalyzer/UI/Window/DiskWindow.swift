import AppKit

/// The analyzer's window, which hands its key equivalents (⌘↑, ⌘⌫, ⌘1–⌘8…) to the controller first: Oriel has no
/// menu bar of its own to carry them.
final class DiskWindow: NSWindow {
    /// Returns true when it handled the event.
    var keyEquivalentHandler: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if keyEquivalentHandler?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
