import AppKit
import SharedUI

/// Highlights clicks during a recording (PLAN §7.4): a transparent, click-through panel over the recorded area
/// draws a fading ring wherever the left (or right) mouse button goes down. The recording's `ClickMonitor` sees the
/// clicks and hands them here.
final class ClickRingOverlay {
    private let panel: FloatingPanel
    private let view: ClickRingView

    /// `frame` is the area that shows rings, in Cocoa screen coordinates.
    init(frame: CGRect) {
        panel = FloatingPanel(contentRect: frame, level: .screenSaver)
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        view = ClickRingView(frame: CGRect(origin: .zero, size: frame.size))
        panel.contentView = view
        panel.setFrame(frame, display: false)
        panel.setAccessibilityElement(false)
    }

    func start() {
        panel.orderFrontRegardless()
    }

    func stop() {
        panel.orderOut(nil)
    }

    /// Draws a ring for `click` when it falls inside the overlay: yellow for the left button, pink for the right.
    func show(_ click: ClickMonitor.Click) {
        guard click.button != .other else { return }
        let frame = panel.frame
        guard frame.contains(click.location) else { return }
        let color: NSColor = click.button == .right ? .systemPink : .systemYellow
        view.ring(
            at: CGPoint(x: click.location.x - frame.minX, y: click.location.y - frame.minY),
            color: color,
            reduceMotion: AccessibilityDisplay.current.reduceMotion
        )
    }
}
