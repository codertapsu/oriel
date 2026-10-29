import AppKit

/// One display's ruler window: borderless and see-through, at screen-saver level, on every Space and over full-screen
/// apps. A non-activating panel that can become key, so Esc, Tab and the arrows reach the ruler even when macOS
/// declines to activate Oriel.
final class RulerWindow: NSPanel {
    let canvas: RulerCanvasView
    let display: RulerDisplay
    weak var handler: RulerEventHandling? {
        didSet { canvas.handler = handler }
    }

    init(screen: NSScreen, display: RulerDisplay, lineColor: NSColor) {
        self.display = display
        canvas = RulerCanvasView(frame: CGRect(origin: .zero, size: screen.frame.size), display: display, lineColor: lineColor)
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        // See-through; set explicitly, mouse events still arrive where nothing is drawn.
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = false
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        isMovable = false
        canvas.autoresizingMask = [.width, .height]
        contentView = canvas
        setFrame(screen.frame, display: false)
        setAccessibilityLabel("Screen Ruler")
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func keyDown(with event: NSEvent) {
        if handler?.rulerKeyDown(event) != true {
            super.keyDown(with: event)
        }
    }

    /// ⌘-keys arrive here first. All of them are taken while the ruler is open, so ⌘Q cannot quit Oriel mid-measurement.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        _ = handler?.rulerKeyDown(event)
        return true
    }
}
