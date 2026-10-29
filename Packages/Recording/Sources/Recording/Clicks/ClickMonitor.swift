import AppKit

/// Sees the mouse buttons go down anywhere while a recording runs, for the click rings and for Auto Zoom's click
/// log (PLAN §7.4, §17). Mouse monitors need no permission, and they run only between `start()` and `stop()`: a
/// click costs one call, and nothing runs in between.
final class ClickMonitor {
    /// One click, where it happened in Cocoa screen coordinates (y up).
    struct Click {
        let location: CGPoint
        let button: ClickRecord.Button
    }

    /// Called on the main thread for every click outside the ignored windows.
    var onClick: ((Click) -> Void)?

    private let ignoredWindows: Set<CGWindowID>
    private var monitors: [Any] = []

    /// Clicks on `ignoredWindows` (the control bar, which the recording leaves out) are not reported.
    init(ignoring ignoredWindows: Set<CGWindowID> = []) {
        self.ignoredWindows = ignoredWindows
    }

    func start() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(global)
        }
        // Clicks on Oriel's own panels, such as the camera bubble, never reach the global monitor.
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
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
    }

    private func handle(_ event: NSEvent) {
        if let window = event.window, ignoredWindows.contains(CGWindowID(clamping: window.windowNumber)) {
            return
        }
        let button: ClickRecord.Button = switch event.type {
        case .leftMouseDown: .left
        case .rightMouseDown: .right
        default: .other
        }
        onClick?(Click(location: NSEvent.mouseLocation, button: button))
    }
}
