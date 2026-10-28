import AppKit
import SharedUI

/// Highlights clicks during a recording (PLAN §7.4): a transparent, click-through panel over the recorded area
/// draws a fading ring wherever the left (or right) mouse button goes down. Mouse monitors need no permission.
final class ClickRingOverlay {
    private let panel: FloatingPanel
    private let view: ClickRingView
    private let ignoredWindows: Set<CGWindowID>
    private var monitors: [Any] = []

    /// `frame` is the area that shows rings, in Cocoa screen coordinates. Clicks on `ignoredWindows` (the control
    /// bar, which the recording leaves out) show no ring.
    init(frame: CGRect, ignoring ignoredWindows: Set<CGWindowID> = []) {
        self.ignoredWindows = ignoredWindows
        panel = FloatingPanel(contentRect: frame, level: .screenSaver)
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        view = ClickRingView(frame: CGRect(origin: .zero, size: frame.size))
        panel.contentView = view
        panel.setFrame(frame, display: false)
        panel.setAccessibilityElement(false)
    }

    func start() {
        guard monitors.isEmpty else { return }
        panel.orderFrontRegardless()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.show(event)
        }) {
            monitors.append(global)
        }
        // Clicks on Oriel's own panels, such as the camera bubble, never reach the global monitor.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.show(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        panel.orderOut(nil)
    }

    private func show(_ event: NSEvent) {
        if let window = event.window, ignoredWindows.contains(CGWindowID(clamping: window.windowNumber)) {
            return
        }
        let location = NSEvent.mouseLocation
        let frame = panel.frame
        guard frame.contains(location) else { return }
        let color: NSColor = event.type == .rightMouseDown ? .systemPink : .systemYellow
        view.ring(
            at: CGPoint(x: location.x - frame.minX, y: location.y - frame.minY),
            color: color,
            reduceMotion: AccessibilityDisplay.current.reduceMotion
        )
    }
}
