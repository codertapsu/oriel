import AppKit

/// Oriel's `NSApplication`. Asked to come forward, it waits one turn of the main actor, so that the window it comes
/// forward for is on screen, and lets `willActivate` put it in the Dock first (`DockPresence`): an app that becomes a
/// regular app while it is already active is reported to keep the menu bar of the app before it (docs/os-quirks.md).
/// Activation is granted later anyway.
final class OrielApplication: NSApplication {
    /// Runs just before every activation Oriel asks for; nil, Oriel comes forward at once.
    var willActivate: (@MainActor () -> Void)?

    override func activate() {
        guard let willActivate else {
            super.activate()
            return
        }
        Task {
            willActivate()
            super.activate()
        }
    }
}
