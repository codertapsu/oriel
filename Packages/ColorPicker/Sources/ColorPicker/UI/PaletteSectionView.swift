import AppKit

/// One palette in the Palettes tab: its name (double-click to rename), how many colors it has, a ⋯ menu for the rest,
/// and its colors.
final class PaletteSectionView: NSView, NSTextFieldDelegate {
    let paletteID: UUID
    let grid = SwatchGridView()
    var onRename: ((String) -> Void)?
    /// The ⋯ menu's items, made when it opens.
    var makeMenu: (() -> NSMenu)?

    private let nameField = NSTextField(string: "")
    private let countLabel = NSTextField(labelWithString: "")
    private let menuButton = NSButton()
    private var name = ""

    init(paletteID: UUID) {
        self.paletteID = paletteID
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        nameField.font = .systemFont(ofSize: 13, weight: .semibold)
        nameField.isBordered = false
        nameField.drawsBackground = false
        nameField.isEditable = false
        nameField.isSelectable = false
        nameField.focusRingType = .none
        nameField.lineBreakMode = .byTruncatingTail
        nameField.delegate = self
        nameField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameField.toolTip = "Double-click to rename"
        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(beginRenaming))
        doubleClick.numberOfClicksRequired = 2
        nameField.addGestureRecognizer(doubleClick)
        countLabel.font = .systemFont(ofSize: 11)
        countLabel.textColor = .secondaryLabelColor
        menuButton.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "Palette actions")
        menuButton.isBordered = false
        menuButton.imagePosition = .imageOnly
        menuButton.contentTintColor = .secondaryLabelColor
        menuButton.toolTip = "Rename, move, export or delete"
        menuButton.target = self
        menuButton.action = #selector(showMenu)
        layOut()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    var isRenaming: Bool {
        nameField.currentEditor() != nil
    }

    func show(_ palette: Palette, selected: UUID?, uppercaseHex: Bool) {
        name = palette.name
        if !isRenaming {
            nameField.stringValue = palette.name
        }
        let count = palette.colors.count
        countLabel.stringValue = count == 1 ? "1 color" : "\(count) colors"
        grid.show(palette.colors, selected: selected, uppercaseHex: uppercaseHex)
        setAccessibilityLabel("\(palette.name), \(countLabel.stringValue)")
    }

    /// Turns the name into a field with the keyboard in it; the panel takes the keyboard only while it is on screen.
    @objc func beginRenaming() {
        guard let window, window.isVisible else { return }
        nameField.isEditable = true
        nameField.isSelectable = true
        nameField.drawsBackground = true
        nameField.backgroundColor = .textBackgroundColor
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nameField)
        nameField.currentEditor()?.selectAll(nil)
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        nameField.stringValue = name
        window?.makeFirstResponder(nil)
        return true
    }

    func controlTextDidEndEditing(_: Notification) {
        nameField.isEditable = false
        nameField.isSelectable = false
        nameField.drawsBackground = false
        let typed = nameField.stringValue
        if typed != name {
            onRename?(typed)
        }
        nameField.stringValue = name
    }

    @objc private func showMenu() {
        guard let menu = makeMenu?() else { return }
        menu.popUp(positioning: nil, at: CGPoint(x: 0, y: menuButton.bounds.maxY + 4), in: menuButton)
    }

    private func layOut() {
        for view in [nameField, countLabel, menuButton, grid] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            nameField.leadingAnchor.constraint(equalTo: leadingAnchor),
            nameField.topAnchor.constraint(equalTo: topAnchor),
            countLabel.leadingAnchor.constraint(equalTo: nameField.trailingAnchor, constant: 8),
            countLabel.firstBaselineAnchor.constraint(equalTo: nameField.firstBaselineAnchor),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: menuButton.leadingAnchor, constant: -8),
            menuButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            menuButton.centerYAnchor.constraint(equalTo: nameField.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 22),
            menuButton.heightAnchor.constraint(equalToConstant: 22),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor),
            grid.topAnchor.constraint(equalTo: nameField.bottomAnchor, constant: 8),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
