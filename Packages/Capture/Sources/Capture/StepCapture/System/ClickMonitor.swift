import AppKit
import OrielCore
import SharedUI

/// Where the user clicks in other apps while Step Capture marks clicks (PLAN §17): an `NSEvent` global monitor for
/// mouse-down, which needs no permission and learns only the pointer's position. Clicks in Oriel's own windows, such
/// as the capture overlay, do not reach it. It exists only while a session marks clicks.
final class ClickMonitor {
    /// Called with each click, in global CoreGraphics points.
    var onClick: ((CGPoint) -> Void)?
    private var monitor: Any?

    var isRunning: Bool {
        monitor != nil
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.clicked() }
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func clicked() {
        onClick?(ScreenGeometry.cgPoint(fromCocoa: NSEvent.mouseLocation, primaryHeight: ScreenLocator.primaryHeight))
    }
}
