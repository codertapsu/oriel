import AppKit
import SharedUI

/// What every switcher tile shares (PLAN §7.1.9, §7.1.10): hover selects and shows the action buttons, a click
/// switches, the selection is a rounded accent fill (plus a border under Increase Contrast), and the tile is
/// an accessibility button labelled "Title — App, minimized, Space 2". Subclasses draw the content.
class TileView: NSView {
    var onHover: (() -> Void)?
    var onClick: (() -> Void)?
    var onAction: ((TileAction) -> Void)?

    private(set) var item: SwitcherItem?
    private(set) var isHovered = false
    private(set) var display = AccessibilityDisplay.current
    let actionBar = TileActionBar()
    private let highlight = CALayer()
    private var trackingArea: NSTrackingArea?

    var isSelected = false {
        didSet {
            guard isSelected != oldValue else { return }
            updateHighlight()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        highlight.cornerRadius = 10
        layer?.addSublayer(highlight)
        actionBar.isHidden = true
        actionBar.onAction = { [weak self] action in self?.onAction?(action) }
        addSubview(actionBar)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    /// Subclasses call super first, then fill in their content.
    func configure(_ item: SwitcherItem, icon _: NSImage?, display: AccessibilityDisplay) {
        self.item = item
        self.display = display
        actionBar.configure(isMinimized: item.entry.info.isMinimized)
        updateHighlight()
        updateActionBar()
        needsLayout = true
    }

    /// Thumbnail-style tiles show it; the others ignore it.
    func setThumbnail(_: CGImage?) {}

    /// Keeps the action buttons above content added later by subclasses.
    func bringActionBarToFront() {
        addSubview(actionBar, positioned: .above, relativeTo: nil)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        highlight.frame = bounds
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateHighlight()
    }

    func updateHighlight() {
        CATransaction.begin()
        CATransaction.setDisableActions(display.reduceMotion)
        CATransaction.setAnimationDuration(0.08)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            highlight.backgroundColor = isSelected ? NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor : nil
            highlight.borderColor = (isSelected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor
        }
        highlight.borderWidth = display.increaseContrast ? (isSelected ? 2 : 1) : 0
        CATransaction.commit()
    }

    // MARK: Mouse

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with _: NSEvent) {
        isHovered = true
        updateActionBar()
        onHover?()
    }

    override func mouseExited(with _: NSEvent) {
        isHovered = false
        updateActionBar()
    }

    override func mouseDown(with _: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) {
            onClick?()
        }
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    private func updateActionBar() {
        actionBar.isHidden = !(isHovered && item?.entry.isActionable == true)
    }

    // MARK: Accessibility

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    override func accessibilityLabel() -> String? {
        item?.accessibilityLabel
    }

    override func isAccessibilitySelected() -> Bool {
        isSelected
    }

    override func accessibilityPerformPress() -> Bool {
        onClick?()
        return true
    }
}
