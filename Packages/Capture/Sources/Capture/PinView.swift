import AppKit
import SharedUI

/// The content of a pinned capture: the image, controls that appear on hover (lock, click-through, close) and a
/// context menu. Dragging it moves the pin; scrolling changes its opacity.
final class PinView: NSView {
    var onCommand: ((PinCommand) -> Void)?
    var isLocked = false {
        didSet { updateLockSymbol() }
    }

    private var controls: NSView?
    private var lockButton: HUDButton?

    init(image: CGImage, size: CGSize) {
        super.init(frame: CGRect(origin: .zero, size: size))
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resize
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
        addControls()
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Pinned capture")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func mouseEntered(with _: NSEvent) {
        controls?.isHidden = false
    }

    override func mouseExited(with _: NSEvent) {
        controls?.isHidden = true
    }

    /// Takes the hover controls away. A click-through pin no longer sees the pointer leave, so they would stay up,
    /// unclickable.
    func hideControls() {
        controls?.isHidden = true
    }

    private func updateLockSymbol() {
        let symbol = isLocked ? "lock.fill" : "lock.open"
        lockButton?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Lock Position")
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 300 : event.scrollingDeltaY / 20
        guard delta != 0 else { return }
        onCommand?(.changeOpacity(by: delta))
    }

    override func menu(for _: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let opacity = NSMenuItem(title: "Opacity", action: nil, keyEquivalent: "")
        let levels = NSMenu()
        for percent in [100, 80, 60, 40, 20] {
            levels.addItem(ActionMenuItem("\(percent) %") { [weak self] in
                self?.onCommand?(.setOpacity(CGFloat(percent) / 100))
            })
        }
        opacity.submenu = levels
        menu.addItem(opacity)
        menu.addItem(item("Click-Through", symbol: "cursorarrow.rays", .toggleClickThrough))
        menu.addItem(item(isLocked ? "Unlock Position" : "Lock Position", symbol: "lock", .toggleLock))
        menu.addItem(.separator())
        menu.addItem(item("Copy", symbol: "doc.on.doc", .copy))
        menu.addItem(item("Save", symbol: "square.and.arrow.down", .save))
        menu.addItem(item("Annotate", symbol: "pencil.tip.crop.circle", .annotate))
        menu.addItem(.separator())
        menu.addItem(item("Close", symbol: "xmark", .close))
        return menu
    }

    private func item(_ title: String, symbol: String, _ command: PinCommand) -> NSMenuItem {
        ActionMenuItem(title, symbol: symbol) { [weak self] in
            self?.onCommand?(command)
        }
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
