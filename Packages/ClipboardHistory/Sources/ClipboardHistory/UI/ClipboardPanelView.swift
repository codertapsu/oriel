import AppKit
import SharedUI

/// The panel's content on glass: the search field and type menu, a banner when needed, the list beside the preview,
/// and a bar of actions with the paste button on the right.
final class ClipboardPanelView: NSView {
    static let size = CGSize(width: 780, height: 500)
    static let listWidth: CGFloat = 330

    let searchField = NSSearchField()
    let filterButton = NSPopUpButton(frame: .zero, pullsDown: false)
    let banner = ClipboardBannerView()
    let table = ClipboardTableView()
    let preview = ClipboardPreviewView()
    let emptyField = NSTextField(wrappingLabelWithString: "")
    let pinButton = ClipboardPanelView.iconButton("pin", label: "Pin")
    let deleteButton = ClipboardPanelView.iconButton("trash", label: "Delete")
    let statusField = NSTextField(labelWithString: "")
    let undoButton = NSButton(title: "Undo", target: nil, action: nil)
    let moreButton = NSPopUpButton(frame: .zero, pullsDown: true)
    let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    let pasteButton = NSButton(title: "Paste", target: nil, action: nil)

    /// Key equivalents (⌘-shortcuts) get here first; returns true when handled.
    var onKeyEquivalent: ((NSEvent) -> Bool)?
    /// Esc when no field takes it.
    var onCancel: (() -> Void)?

    private let background = Material.make(cornerRadius: 22)
    private let scroll = NSScrollView()
    private var bannerHeight: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureControls()
        configureTable()
        layOut()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Clipboard History")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
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

    func showBanner(_ message: ClipboardBannerView.Message?) {
        banner.isHidden = message == nil
        bannerHeight?.isActive = message == nil
        if let message {
            banner.show(message)
        }
    }

    func showUndo(_ text: String?) {
        undoButton.isHidden = text == nil
        if let text {
            undoButton.title = "Undo"
            undoButton.toolTip = text
            statusField.stringValue = text
        }
    }

    private func configureControls() {
        searchField.placeholderString = "Search clipboard history"
        searchField.font = .systemFont(ofSize: 15)
        searchField.controlSize = .large
        searchField.focusRingType = .none
        searchField.sendsSearchStringImmediately = true
        searchField.setAccessibilityLabel("Search clipboard history")
        filterButton.controlSize = .large
        filterButton.setContentHuggingPriority(.required, for: .horizontal)
        for filter in ClipboardFilter.allCases {
            filterButton.addItem(withTitle: filter.title)
            filterButton.lastItem?.image = NSImage(systemSymbolName: filter.symbol, accessibilityDescription: nil)
        }
        emptyField.font = .systemFont(ofSize: 13)
        emptyField.textColor = .secondaryLabelColor
        emptyField.alignment = .center
        statusField.font = .systemFont(ofSize: 12)
        statusField.textColor = .secondaryLabelColor
        statusField.lineBreakMode = .byTruncatingTail
        statusField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        undoButton.bezelStyle = .push
        undoButton.controlSize = .small
        undoButton.isHidden = true
        moreButton.isBordered = false
        moreButton.addItem(withTitle: "")
        moreButton.lastItem?.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "More")
        (moreButton.cell as? NSPopUpButtonCell)?.arrowPosition = .noArrow
        moreButton.setAccessibilityLabel("More")
        moreButton.toolTip = "More"
        for button in [copyButton, pasteButton] {
            button.bezelStyle = .push
            button.controlSize = .large
        }
        pasteButton.keyEquivalent = "\r"
        pasteButton.imagePosition = .imageLeading
        pasteButton.imageScaling = .scaleProportionallyDown
        pasteButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    /// A borderless symbol button for the action bar.
    private static func iconButton(_ symbol: String, label: String) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage(),
            target: nil,
            action: nil
        )
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .labelColor
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 28),
            button.heightAnchor.constraint(equalToConstant: 28),
        ])
        return button
    }

    private func configureTable() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("item"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.style = .inset
        table.backgroundColor = .clear
        table.rowSizeStyle = .custom
        table.intercellSpacing = NSSize(width: 0, height: 2)
        table.allowsMultipleSelection = true
        table.allowsEmptySelection = true
        table.floatsGroupRows = false
        table.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        table.draggingDestinationFeedbackStyle = .gap
        table.setAccessibilityLabel("Clipboard items")
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.contentView.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
    }

    private func layOut() {
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        let content = background.contentView
        let header = NSStackView(views: [searchField, filterButton])
        header.spacing = 8
        header.distribution = .fill
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let divider = NSBox()
        divider.boxType = .separator
        let footerLine = NSBox()
        footerLine.boxType = .separator
        let footer = NSStackView()
        footer.setViews([pinButton, deleteButton, statusField, undoButton], in: .leading)
        footer.setViews([moreButton, copyButton, pasteButton], in: .trailing)
        footer.spacing = 8
        for view in [header, banner, scroll, emptyField, divider, preview, footerLine, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        let bannerHeight = banner.heightAnchor.constraint(equalToConstant: 0)
        self.bannerHeight = bannerHeight
        banner.isHidden = true
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            banner.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            banner.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 10),
            bannerHeight,
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
            scroll.widthAnchor.constraint(equalToConstant: Self.listWidth),
            scroll.topAnchor.constraint(equalTo: banner.bottomAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: footerLine.topAnchor, constant: -4),
            emptyField.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyField.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            emptyField.widthAnchor.constraint(equalTo: scroll.widthAnchor, constant: -48),
            divider.leadingAnchor.constraint(equalTo: scroll.trailingAnchor, constant: 6),
            divider.topAnchor.constraint(equalTo: scroll.topAnchor),
            divider.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            preview.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            preview.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            preview.topAnchor.constraint(equalTo: scroll.topAnchor),
            preview.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            footerLine.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            footerLine.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footerLine.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -8),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
            footer.heightAnchor.constraint(equalToConstant: 32),
        ])
    }
}
