import AppKit
import OrielCore
import SharedUI

/// The content of a pinned capture (PLAN §10.4, §17): the image, controls that appear on hover (lock, click-through,
/// close) and a context menu. Dragging moves the pin; scrolling or pinching zooms it around the pointer; ⌥ and the
/// scroll wheel change its opacity, and so do the number keys (1 is 10 %, 0 is 100 %). While the pin is the window in
/// front, ⌘C copies, ⌘S saves, ⌘W or Delete closes, ⌘+, ⌘− and ⌘0 zoom and the arrows move it.
final class PinView: NSView {
    var onCommand: ((PinCommand) -> Void)?
    /// The items of the context menu, built when it opens so that they show the pin's state.
    var menuItems: (() -> [NSMenuItem])?
    var isLocked = false {
        didSet { updateLockSymbol() }
    }

    var showsBorder = true {
        didSet { needsDisplay = true }
    }

    /// ⌥⌘ holds a click-through pin open: it shows its controls and an accent outline while it takes clicks.
    var isHeldOpen = false {
        didSet {
            needsDisplay = true
            controls?.isHidden = !isHeldOpen
        }
    }

    /// Nearest-neighbour scaling from 200 %, so pixels stay crisp when zoomed in.
    var zoom: CGFloat = 1 {
        didSet { layer?.magnificationFilter = zoom >= 2 ? .nearest : .linear }
    }

    private let image: CGImage
    private var controls: NSView?
    private var lockButton: HUDButton?
    /// "60 %" in a dark pill, for a moment after the opacity or the zoom changes.
    private let badge = NSView()
    private let badgeLabel = NSTextField(labelWithString: "")
    private var badgeDismissal: Task<Void, Never>?

    init(image: CGImage, size: CGSize) {
        self.image = image
        super.init(frame: CGRect(origin: .zero, size: size))
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resize
        layer?.minificationFilter = .trilinear
        layer?.masksToBounds = true
        addBadge()
        addControls()
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Pinned capture")
        setAccessibilityHelp("Drag to move, scroll to zoom, Option and scroll to fade. The context menu has the rest.")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    /// A click makes the pin the key window, without activating Oriel, so its keys work.
    override var needsPanelToBecomeKey: Bool {
        true
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    /// The border follows the appearance: a hairline separator, or the accent colour while held open.
    override func updateLayer() {
        guard let layer else { return }
        layer.contents = image
        if isHeldOpen {
            layer.borderWidth = 2
            layer.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            layer.borderWidth = showsBorder ? 1 : 0
            layer.borderColor = NSColor.separatorColor.cgColor
        }
        layer.cornerRadius = showsBorder || isHeldOpen ? 4 : 0
    }

    override func mouseEntered(with _: NSEvent) {
        controls?.isHidden = false
    }

    override func mouseExited(with _: NSEvent) {
        controls?.isHidden = !isHeldOpen
    }

    /// Takes the hover controls away. A click-through pin no longer sees the pointer leave, so they would stay up,
    /// unclickable.
    func hideControls() {
        controls?.isHidden = true
    }

    /// Shows `text` ("60 %", "150 %") in the middle of the pin for a moment.
    func showValue(_ text: String) {
        badgeLabel.stringValue = text
        badgeLabel.sizeToFit()
        let label = badgeLabel.frame.size
        let size = CGSize(width: label.width + 20, height: label.height + 10)
        badge.frame = CGRect(
            x: (bounds.midX - size.width / 2).rounded(),
            y: (bounds.midY - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        )
        badgeLabel.setFrameOrigin(CGPoint(x: 10, y: ((size.height - label.height) / 2).rounded()))
        badge.isHidden = false
        badgeDismissal?.cancel()
        badgeDismissal = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.badge.isHidden = true
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        guard delta != 0 else { return }
        if event.modifierFlags.contains(.option) {
            onCommand?(.changeOpacity(by: PinState.opacityChange(scrollDelta: delta, precise: event.hasPreciseScrollingDeltas)))
        } else {
            let factor = PinState.zoomFactor(scrollDelta: delta, precise: event.hasPreciseScrollingDeltas)
            onCommand?(.zoom(by: factor, anchor: NSEvent.mouseLocation))
        }
    }

    override func magnify(with event: NSEvent) {
        onCommand?(.zoom(by: 1 + event.magnification, anchor: NSEvent.mouseLocation))
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let plain = flags.isDisjoint(with: [.command, .control, .option])
        if plain, let digit = Self.digits[event.keyCode], let opacity = PinState.opacity(forDigit: digit) {
            onCommand?(.setOpacity(opacity))
            return
        }
        let step: CGFloat = flags.contains(.shift) ? 10 : 1
        switch event.keyCode {
        case KeyCode.leftArrow: onCommand?(.move(dx: -step, dy: 0))
        case KeyCode.rightArrow: onCommand?(.move(dx: step, dy: 0))
        case KeyCode.upArrow: onCommand?(.move(dx: 0, dy: step))
        case KeyCode.downArrow: onCommand?(.move(dx: 0, dy: -step))
        case KeyCode.delete, KeyCode.forwardDelete: onCommand?(.close)
        case KeyCode.escape: break
        default: super.keyDown(with: event)
        }
    }

    /// ⌘C, ⌘S, ⌘W and the zoom keys, by the character they type, so they work on any keyboard layout.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, window?.isKeyWindow == true else { return super.performKeyEquivalent(with: event) }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), flags.isDisjoint(with: [.control, .option]) else { return super.performKeyEquivalent(with: event) }
        let keys = Set([event.characters, event.charactersIgnoringModifiers].compactMap { $0?.lowercased() })
        let command: PinCommand? = if keys.contains("c") {
            .copy
        } else if keys.contains("s") {
            .save
        } else if keys.contains("w") {
            .close
        } else if !keys.isDisjoint(with: ["=", "+"]) {
            .zoomIn
        } else if keys.contains("-") {
            .zoomOut
        } else if keys.contains("0") {
            .actualSize
        } else {
            nil
        }
        guard let command else { return super.performKeyEquivalent(with: event) }
        onCommand?(command)
        return true
    }

    /// Edit → Copy, when the pin is in front.
    @objc func copy(_: Any?) {
        onCommand?(.copy)
    }

    override func menu(for _: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        for item in menuItems?() ?? [] {
            menu.addItem(item)
        }
        return menu
    }

    /// The number row and the keypad, by key position.
    private static let digits: [UInt16: Int] = [
        29: 0, 18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6, 26: 7, 28: 8, 25: 9,
        82: 0, 83: 1, 84: 2, 85: 3, 86: 4, 87: 5, 88: 6, 89: 7, 91: 8, 92: 9,
    ]

    private func updateLockSymbol() {
        let symbol = isLocked ? "lock.fill" : "lock.open"
        lockButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: isLocked ? "Unlock Position" : "Lock Position")
        lockButton?.toolTip = isLocked ? "Unlock Position" : "Lock Position"
    }

    private func addBadge() {
        badgeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.setAccessibilityElement(false)
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor(white: 0, alpha: 0.6).cgColor
        badge.layer?.cornerRadius = 8
        badge.isHidden = true
        badge.addSubview(badgeLabel)
        addSubview(badge)
    }

    private func addControls() {
        let lock = HUDButton(symbol: "lock.open", label: "Lock Position") { [weak self] in self?.onCommand?(.toggleLock) }
        let through = HUDButton(symbol: "cursorarrow.rays", label: "Click-Through") { [weak self] in
            self?.onCommand?(.toggleClickThrough)
        }
        let close = HUDButton(symbol: "xmark", label: "Close") { [weak self] in self?.onCommand?(.close) }
        let stack = NSStackView(views: [lock, through, close])
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let background = Material.make(cornerRadius: 9)
        background.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(stack)
        background.isHidden = true
        addSubview(background)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            background.topAnchor.constraint(equalTo: topAnchor, constant: 6),
        ])
        controls = background
        lockButton = lock
    }
}
