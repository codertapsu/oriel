import AppKit

/// Instant Capture's panel: borderless, exactly over the selection, above other apps and the menu bar, and able to
/// take the keyboard without activating Oriel, so the app the user was in stays in front. It delivers the editor's
/// keys like the editor window does, and the standard editing shortcuts to a label being typed.
final class InstantPanel: NSPanel {
    /// Runs an editor command for a key press; returns whether it was handled.
    var commandHandler: ((EditorCommand) -> Bool)?

    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.fullScreenAuxiliary, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        // No shadow and no animation: the capture must look like the screen it covers, from the first frame.
        hasShadow = false
        animationBehavior = .none
        isMovable = false
        isReleasedWhenClosed = false
        setAccessibilityLabel("Instant Capture")
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        if let textView = firstResponder as? NSTextView, EditorWindow.performTextEditingShortcut(event, in: textView) {
            return true
        }
        if let command = EditorShortcuts.command(for: event), commandHandler?(command) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if let command = EditorShortcuts.command(for: event), commandHandler?(command) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_: Any?) {
        _ = commandHandler?(.cancel)
    }
}
