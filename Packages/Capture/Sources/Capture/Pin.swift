import AppKit
import OrielCore
import SharedUI

/// One pinned capture (PLAN §10.4): a floating panel above other windows on every Space, moved by dragging, with an
/// opacity, click-through and a position lock. While it is click-through a small button beside it turns that off
/// again, since the pin itself no longer receives clicks.
final class Pin {
    let result: CaptureResult
    let panel: FloatingPanel
    var onCommand: ((PinCommand, Pin) -> Void)?
    private let view: PinView
    private var releasePanel: FloatingPanel?
    private(set) var isLocked = false
    private(set) var isClickThrough = false
    private var isPassingThrough = false

    init(result: CaptureResult, frame: CGRect) {
        self.result = result
        panel = FloatingPanel(contentRect: frame, level: .floating, joinsAllSpaces: true)
        panel.isMovableByWindowBackground = true
        panel.setAccessibilityLabel("Pinned capture")
        view = PinView(image: result.image, size: frame.size)
        panel.contentView = view
        panel.setFrame(frame, display: false)
        view.onCommand = { [weak self] command in
            guard let self else { return }
            onCommand?(command, self)
        }
    }

    func show() {
        panel.orderFrontRegardless()
    }

    func close() {
        setReleaseButton(visible: false)
        panel.orderOut(nil)
    }

    func setOpacity(_ value: CGFloat) {
        panel.alphaValue = min(max(value, 0.1), 1)
    }

    func toggleLock() {
        isLocked.toggle()
        panel.isMovableByWindowBackground = !isLocked
        view.isLocked = isLocked
    }

    func toggleClickThrough() {
        isClickThrough.toggle()
        panel.ignoresMouseEvents = isClickThrough || isPassingThrough
        if isClickThrough {
            view.hideControls()
        }
        setReleaseButton(visible: isClickThrough)
    }

    /// While a scrolling capture runs, every pin lets the mouse through, so scroll events reach the app underneath
    /// even where a pin covers the region.
    func setPassingThrough(_ passing: Bool) {
        isPassingThrough = passing
        panel.ignoresMouseEvents = isClickThrough || passing
        releasePanel?.ignoresMouseEvents = passing
    }

    private func setReleaseButton(visible: Bool) {
        if let releasePanel {
            panel.removeChildWindow(releasePanel)
            releasePanel.orderOut(nil)
            self.releasePanel = nil
        }
        guard visible else { return }
        let size: CGFloat = 32
        let frame = CGRect(x: panel.frame.maxX - size - 4, y: panel.frame.maxY - size - 4, width: size, height: size)
        let badge = FloatingPanel(contentRect: frame, level: .floating, joinsAllSpaces: true)
        let background = Material.make(cornerRadius: size / 2)
        let button = HUDButton(symbol: "cursorarrow.click", label: "Stop Click-Through") { [weak self] in
            self?.toggleClickThrough()
        }
        background.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: background.contentView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: background.contentView.centerYAnchor),
        ])
        badge.contentView = background
        badge.setFrame(frame, display: false)
        panel.addChildWindow(badge, ordered: .above)
        badge.orderFrontRegardless()
        releasePanel = badge
    }
}
