import AppKit
import OrielCore
import SharedUI

/// All pinned captures. A pin opens where the capture was taken, at its point size (scaled down to fit the screen).
///
/// While any pin is click-through, ⌥⌘ held with the pointer over it holds it open, so it takes clicks until they are
/// let go. That needs to see the pointer move over other apps, which an `NSEvent` global monitor does without any
/// permission; with Accessibility it sees ⌥⌘ go down too, so the pin opens without the pointer moving. The monitors
/// exist only while a pin is click-through.
final class PinController {
    /// The modifier keys that hold a click-through pin open.
    static let holdModifiers: NSEvent.ModifierFlags = [.option, .command]

    /// Copy, save and annotate are the coordinator's to do.
    var perform: ((PinCommand, CaptureResult) -> Void)?
    /// Called whenever a pin opens or closes, because Oriel's own windows are left out of every capture.
    var windowsChanged: (() -> Void)?
    private var pins: [Pin] = []
    private var holdMonitors: [Any] = []
    /// Whether a global monitor may watch modifier keys, which macOS allows only with Accessibility.
    private let watchesModifierKeys: () -> Bool

    init(watchesModifierKeys: @escaping () -> Bool = { false }) {
        self.watchesModifierKeys = watchesModifierKeys
    }

    var count: Int {
        pins.count
    }

    /// What is pinned, oldest first.
    var results: [CaptureResult] {
        pins.map(\.result)
    }

    /// What is pinned and how each pin is, oldest first, for the status menu.
    var entries: [PinsMenu.Entry] {
        pins.map { PinsMenu.Entry(result: $0.result, state: $0.state) }
    }

    func pin(_ result: CaptureResult) {
        let pin = Pin(result: result, frame: Self.frame(for: result))
        pin.onCommand = { [weak self] command, pin in
            self?.handle(command, for: pin)
        }
        pins.append(pin)
        pin.show()
        windowsChanged?()
    }

    /// Runs `command` on the pin showing capture `id`, from the status menu.
    func perform(_ command: PinCommand, on id: UUID) {
        guard let pin = pins.first(where: { $0.result.id == id }) else { return }
        handle(command, for: pin)
    }

    /// Brings the pin showing capture `id` to the front.
    func reveal(_ id: UUID) {
        perform(.bringToFront, on: id)
    }

    /// The status menu's way back: every pin takes clicks again.
    func stopClickThroughOnAllPins() {
        for pin in pins where pin.state.isClickThrough {
            pin.toggleClickThrough()
        }
        clickThroughChanged()
    }

    func closeAll() {
        for pin in pins {
            pin.close()
        }
        pins.removeAll()
        clickThroughChanged()
        windowsChanged?()
    }

    /// Lets the mouse through every pin while a scrolling capture runs (see `Pin.setPassingThrough`).
    func setPassingThrough(_ passing: Bool) {
        for pin in pins {
            pin.setPassingThrough(passing)
        }
    }

    private func handle(_ command: PinCommand, for pin: Pin) {
        switch command {
        case .close:
            pin.close()
            pins.removeAll { $0 === pin }
            clickThroughChanged()
            windowsChanged?()
        case .bringToFront:
            pin.bringToFront()
        case .toggleLock:
            pin.toggleLock()
        case .toggleClickThrough:
            pin.toggleClickThrough()
            clickThroughChanged()
        case .toggleBorder:
            pin.toggleBorder()
        case let .setOpacity(value):
            pin.setOpacity(value)
        case let .changeOpacity(delta):
            pin.setOpacity(pin.state.opacity + delta)
        case .zoomIn:
            pin.zoomIn()
        case .zoomOut:
            pin.zoomOut()
        case .actualSize:
            pin.zoom(to: 1, anchor: nil)
        case let .zoom(factor, anchor):
            pin.zoom(to: pin.state.zoom * factor, anchor: anchor)
        case let .move(dx, dy):
            pin.move(dx: dx, dy: dy)
        case .copy, .save, .annotate:
            perform?(command, pin.result)
        }
    }

    // MARK: - Holding a click-through pin open

    /// Installs the monitors when the first pin becomes click-through and removes them after the last; the release
    /// button's window came or went too.
    private func clickThroughChanged() {
        let needed = pins.contains { $0.state.isClickThrough }
        if needed, holdMonitors.isEmpty {
            installHoldMonitors()
        } else if !needed, !holdMonitors.isEmpty {
            removeHoldMonitors()
        }
        updateHeldOpen()
        windowsChanged?()
    }

    private func installHoldMonitors() {
        var global: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if watchesModifierKeys() {
            global.insert(.flagsChanged)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: global, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHeldOpen() }
        }) {
            holdMonitors.append(monitor)
        }
        // Over a pin held open the events are Oriel's own, which the global monitor does not see.
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .flagsChanged], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updateHeldOpen() }
            return event
        }) {
            holdMonitors.append(monitor)
        }
    }

    private func removeHoldMonitors() {
        for monitor in holdMonitors {
            NSEvent.removeMonitor(monitor)
        }
        holdMonitors = []
    }

    /// A click-through pin is held open while ⌥⌘ are down and the pointer is over it; a drag that began while it was
    /// held open finishes first.
    private func updateHeldOpen() {
        let held = NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).isSuperset(of: Self.holdModifiers)
        let pointer = NSEvent.mouseLocation
        let dragging = NSEvent.pressedMouseButtons != 0
        for pin in pins where pin.state.isClickThrough {
            if pin.state.isHeldOpen, dragging {
                continue
            }
            pin.setHeldOpen(held && pin.panel.frame.contains(pointer))
        }
    }

    // MARK: - Placement

    /// The capture's own place and point size when it fits, else scaled to 70 % of the screen and centred.
    private static func frame(for result: CaptureResult) -> CGRect {
        let rect = result.rect
        let screen = (rect.isEmpty ? nil : ScreenLocator.screen(containing: rect)) ?? ScreenLocator.screenUnderMouse
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        var size = result.pointSize
        let limit = CGSize(width: visible.width * 0.7, height: visible.height * 0.7)
        let factor = min(1, limit.width / max(size.width, 1), limit.height / max(size.height, 1))
        size = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        var frame = CGRect(origin: .zero, size: size)
        if factor == 1, !rect.isEmpty {
            frame.origin = ScreenLocator.cocoaRect(fromCG: rect).origin
        } else {
            frame.origin = CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        }
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - size.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - size.height)
        return frame
    }
}
