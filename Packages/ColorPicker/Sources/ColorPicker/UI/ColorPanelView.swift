import AppKit
import SharedUI

/// The panel's content on glass: the tabs, the eyedropper and the close button along the top, one tab below, and a
/// footer for what just happened ("Copied HEX") with Undo after a deletion. Keys reach the controller through
/// `onKeyDown` and `onKeyEquivalent` whenever no field is being edited.
final class ColorPanelView: NSView {
    static let size = CGSize(width: 420, height: 680)

    let tabs = NSSegmentedControl(labels: ColorPanelTab.allCases.map(\.title), trackingMode: .selectOne, target: nil, action: nil)
    let pickButton = NSButton()
    let closeButton = NSButton()
    let colorTab = ColorTabView()
    let palettesTab = PalettesTabView()
    let contrastTab = ContrastTabView()
    let statusLabel = NSTextField(labelWithString: "")
    let undoButton = NSButton(title: "Undo", target: nil, action: nil)

    var onKeyDown: ((NSEvent) -> Bool)?
    var onKeyEquivalent: ((NSEvent) -> Bool)?
    var onCancel: (() -> Void)?

    private let background = Material.make(cornerRadius: 20)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureControls()
        layOut()
        show(.color)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Color Picker")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var selectedTab: ColorPanelTab {
        ColorPanelTab(rawValue: tabs.selectedSegment) ?? .color
    }

    func show(_ tab: ColorPanelTab) {
        tabs.selectedSegment = tab.rawValue
        colorTab.isHidden = tab != .color
        palettesTab.isHidden = tab != .palettes
        contrastTab.isHidden = tab != .contrast
    }

    func showStatus(_ text: String?, undo: Bool) {
        statusLabel.stringValue = text ?? ""
        undoButton.isHidden = !undo
    }

    // MARK: Keys

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if onKeyEquivalent?(event) == true {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }

    /// A click on the background takes focus from a field, so the number keys copy again.
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    private func configureControls() {
        tabs.segmentStyle = .automatic
        tabs.controlSize = .regular
        for tab in ColorPanelTab.allCases {
            tabs.setToolTip("\(tab.title) (⌘\(tab.rawValue + 1))", forSegment: tab.rawValue)
        }
        tabs.setAccessibilityLabel("Color Picker sections")
        pickButton.image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "Pick a color from the screen")
        pickButton.bezelStyle = .push
        pickButton.imagePosition = .imageOnly
        pickButton.toolTip = "Pick a color from the screen"
        closeButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close")
        closeButton.isBordered = false
        closeButton.imagePosition = .imageOnly
        closeButton.contentTintColor = .tertiaryLabelColor
        closeButton.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        closeButton.toolTip = "Close (Esc)"
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        undoButton.bezelStyle = .push
        undoButton.controlSize = .small
        undoButton.isHidden = true
    }

    private func layOut() {
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        let content = background.contentView
        let footerLine = NSBox()
        footerLine.boxType = .separator
        let views: [NSView] = [tabs, pickButton, closeButton, colorTab, palettesTab, contrastTab, footerLine, statusLabel, undoButton]
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        let inset: CGFloat = 16
        var constraints = [
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            tabs.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: inset),
            tabs.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            closeButton.centerYAnchor.constraint(equalTo: tabs.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 22),
            pickButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            pickButton.centerYAnchor.constraint(equalTo: tabs.centerYAnchor),
            footerLine.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            footerLine.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footerLine.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -34),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: inset),
            statusLabel.centerYAnchor.constraint(equalTo: footerLine.bottomAnchor, constant: 17),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: undoButton.leadingAnchor, constant: -8),
            undoButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            undoButton.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
        ]
        for tab in [colorTab, palettesTab, contrastTab] as [NSView] {
            constraints += [
                tab.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: inset),
                tab.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -inset),
                tab.topAnchor.constraint(equalTo: tabs.bottomAnchor, constant: 14),
                tab.bottomAnchor.constraint(equalTo: footerLine.topAnchor, constant: -12),
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }
}
