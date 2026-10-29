import AppKit
import OrielCore
import SharedUI

/// One pinned capture (PLAN §10.4, §17): a floating panel above other windows on every Space, moved by dragging, with
/// an opacity, a zoom, click-through, a position lock and a border with its shadow (`PinState`). While it is
/// click-through a small button beside it turns that off again, since the pin itself no longer receives clicks; so do
/// ⌥⌘ held over it and the status menu's Pinned submenu.
final class Pin {
    let result: CaptureResult
    let panel: FloatingPanel
    var onCommand: ((PinCommand, Pin) -> Void)?
    private(set) var state = PinState()
    private let view: PinView
    private var releasePanel: FloatingPanel?

    /// `frame` (Cocoa screen coordinates) sets the starting zoom: the capture's point size fitted into it.
    init(result: CaptureResult, frame: CGRect) {
        self.result = result
        panel = FloatingPanel(contentRect: frame, level: .floating, joinsAllSpaces: true)
        panel.allowsKey = true
        panel.acceptsMouseMovedEvents = true
        panel.isMovableByWindowBackground = true
        panel.setAccessibilityLabel("Pinned capture")
        view = PinView(image: result.image, size: frame.size)
        panel.contentView = view
        panel.initialFirstResponder = view
        panel.setFrame(frame, display: false)
        let pointWidth = result.pointSize.width
        state.setZoom(pointWidth > 0 ? frame.width / pointWidth : 1)
        view.zoom = state.zoom
        view.onCommand = { [weak self] command in
            guard let self else { return }
            onCommand?(command, self)
        }
        view.menuItems = { [weak self] in
            guard let self else { return [] }
            return PinsMenu.commandItems(for: state) { [weak self] command in
                guard let self else { return }
                onCommand?(command, self)
            }
        }
    }

    func show() {
        panel.orderFrontRegardless()
    }

    /// In front of everything, ready for its keys.
    func bringToFront() {
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(view)
    }

    func close() {
        setReleaseButton(visible: false)
        panel.orderOut(nil)
    }

    func setOpacity(_ value: CGFloat) {
        state.setOpacity(value)
        apply()
        view.showValue("\(state.opacityPercent) %")
    }

    func toggleLock() {
        state.isLocked.toggle()
        apply()
    }

    func toggleBorder() {
        state.showsBorder.toggle()
        apply()
    }

    func toggleClickThrough() {
        state.isClickThrough.toggle()
        state.isHeldOpen = false
        if state.isClickThrough {
            view.hideControls()
        }
        apply()
        setReleaseButton(visible: state.isClickThrough)
    }

    /// While a scrolling capture runs, every pin lets the mouse through, so scroll events reach the app underneath
    /// even where a pin covers the region.
    func setPassingThrough(_ passing: Bool) {
        state.isPassingThrough = passing
        apply()
        releasePanel?.ignoresMouseEvents = passing
    }

    /// ⌥⌘ is held over a click-through pin, or let go.
    func setHeldOpen(_ held: Bool) {
        guard state.isClickThrough, state.isHeldOpen != held else { return }
        state.isHeldOpen = held
        apply()
    }

    /// Zooms to `value` (1 is the capture's point size), keeping `anchor` (Cocoa screen coordinates; the middle when
    /// nil) over the same point of the capture.
    func zoom(to value: CGFloat, anchor: CGPoint?) {
        state.setZoom(value)
        let frame = panel.frame
        let resized = PinState.frame(
            of: frame,
            resizedTo: state.size(for: result.pointSize),
            keeping: anchor ?? CGPoint(x: frame.midX, y: frame.midY)
        )
        panel.setFrame(resized, display: true)
        view.zoom = state.zoom
        placeReleaseButton()
        view.showValue("\(state.zoomPercent) %")
    }

    func zoomIn() {
        var next = state
        next.zoomIn()
        zoom(to: next.zoom, anchor: nil)
    }

    func zoomOut() {
        var next = state
        next.zoomOut()
        zoom(to: next.zoom, anchor: nil)
    }

    /// Moves the pin by whole points (the arrow keys); a locked pin stays where it is.
    func move(dx: CGFloat, dy: CGFloat) {
        guard !state.isLocked else {
            NSSound.beep()
            return
        }
        panel.setFrameOrigin(CGPoint(x: panel.frame.minX + dx, y: panel.frame.minY + dy))
    }

    private func apply() {
        panel.alphaValue = state.opacity
        panel.ignoresMouseEvents = state.ignoresMouseEvents
        panel.isMovableByWindowBackground = !state.isLocked
        panel.hasShadow = state.showsBorder
        view.isLocked = state.isLocked
        view.showsBorder = state.showsBorder
        view.isHeldOpen = state.isHeldOpen
        panel.invalidateShadow()
    }

    private func setReleaseButton(visible: Bool) {
        if let releasePanel {
            panel.removeChildWindow(releasePanel)
            releasePanel.orderOut(nil)
            self.releasePanel = nil
        }
        guard visible else { return }
        let badge = FloatingPanel(contentRect: releaseFrame, level: .floating, joinsAllSpaces: true)
        let background = Material.make(cornerRadius: Self.releaseSize / 2)
        let button = HUDButton(symbol: "cursorarrow.click", label: "Stop Click-Through") { [weak self] in
            self?.toggleClickThrough()
        }
        background.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: background.contentView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: background.contentView.centerYAnchor),
        ])
        badge.contentView = background
        badge.setFrame(releaseFrame, display: false)
        badge.setAccessibilityLabel("Stop Click-Through")
        panel.addChildWindow(badge, ordered: .above)
        badge.orderFrontRegardless()
        releasePanel = badge
    }

    private static let releaseSize: CGFloat = 32

    /// The top-right corner of the pin, inside it.
    private var releaseFrame: CGRect {
        let size = Self.releaseSize
        return CGRect(x: panel.frame.maxX - size - 4, y: panel.frame.maxY - size - 4, width: size, height: size)
    }

    private func placeReleaseButton() {
        releasePanel?.setFrame(releaseFrame, display: false)
    }
}
