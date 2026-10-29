import AppKit
import OrielCore
import SharedUI

/// The events Translate Under Cursor follows while it is on (PLAN §17), from `NSEvent` monitors and nothing else:
/// pointer movements; scrolls, which move the text under a still pointer; and clicks, drags and key presses, which mean
/// the user is busy with something else. Key presses reach a global monitor only with Accessibility, which macOS
/// requires for them; without it, Esc works only in Oriel's own windows, and the shortcut still turns the mode off. Of
/// a key press, only whether it is Esc is looked at. Everything is removed by `stop()`.
@MainActor
final class CursorEventMonitor {
    var onMove: (@MainActor (CGPoint) -> Void)?
    var onScroll: (@MainActor () -> Void)?
    var onDismiss: (@MainActor () -> Void)?
    var onEscape: (@MainActor () -> Void)?

    private var monitors: [Any] = []

    /// `watchesKeys` installs the global key monitor; pass whether Oriel has Accessibility.
    func start(watchesKeys: Bool) {
        stop()
        var global: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .scrollWheel, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        if watchesKeys {
            global.insert(.keyDown)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: global, handler: { [weak self] event in
            let type = event.type
            let isEscape = type == .keyDown && Self.isEscape(event)
            MainActor.assumeIsolated { self?.handle(type, isEscape: isEscape) }
        }) {
            monitors.append(monitor)
        }
        // Esc while an Oriel window is in front, which the global monitor does not see.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            let isEscape = Self.isEscape(event)
            MainActor.assumeIsolated { self?.handle(.keyDown, isEscape: isEscape) }
            return event
        }) {
            monitors.append(monitor)
        }
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors = []
    }

    private func handle(_ type: NSEvent.EventType, isEscape: Bool) {
        switch type {
        case .mouseMoved:
            onMove?(Self.pointerLocation)
        case .scrollWheel:
            onScroll?()
        case .keyDown where isEscape:
            onEscape?()
        default:
            onDismiss?()
        }
    }

    /// Esc with no modifier but Fn.
    private nonisolated static func isEscape(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.function, .numericPad, .capsLock])
        return event.keyCode == KeyCode.escape && modifiers.isEmpty
    }

    /// The pointer in global points, top-left origin.
    static var pointerLocation: CGPoint {
        let location = NSEvent.mouseLocation
        return CGPoint(x: location.x, y: ScreenLocator.primaryHeight - location.y)
    }
}
