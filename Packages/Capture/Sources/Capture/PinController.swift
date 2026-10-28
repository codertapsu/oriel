import AppKit
import OrielCore
import SharedUI

/// All pinned captures. A pin opens where the capture was taken, at its point size (scaled down to fit the screen).
final class PinController {
    /// Copy, save and annotate are the coordinator's to do.
    var perform: ((PinCommand, CaptureResult) -> Void)?
    /// Called whenever a pin opens or closes, because Oriel's own windows are left out of every capture.
    var windowsChanged: (() -> Void)?
    private var pins: [Pin] = []

    var count: Int {
        pins.count
    }

    /// What is pinned, oldest first.
    var results: [CaptureResult] {
        pins.map(\.result)
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

    /// Brings the pin showing capture `id` to the front.
    func reveal(_ id: UUID) {
        pins.first { $0.result.id == id }?.show()
    }

    func closeAll() {
        for pin in pins {
            pin.close()
        }
        pins.removeAll()
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
            windowsChanged?()
        case .toggleLock:
            pin.toggleLock()
        case .toggleClickThrough:
            pin.toggleClickThrough()
            windowsChanged?()
        case let .setOpacity(value):
            pin.setOpacity(value)
        case let .changeOpacity(delta):
            pin.setOpacity(pin.panel.alphaValue + delta)
        case .copy, .save, .annotate:
            perform?(command, pin.result)
        }
    }

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
