import AppKit

/// The bar under the palettes that shows the selected palette color: its swatch, a field to name it (exports use the
/// name) and a button that removes it from its palette. With nothing selected it says how the tab works.
final class PaletteColorDetailView: NSView, NSTextFieldDelegate {
    var onRename: ((String) -> Void)?
    var onRemove: (() -> Void)?

    private let swatch = SwatchButton(color: .white, side: 26)
    private let nameField = NSTextField(string: "")
    private let valueLabel = NSTextField(labelWithString: "")
    private let removeButton = NSButton()
    private let hint =
        NSTextField(wrappingLabelWithString: "Click a color to select it. Drag colors to reorder them or into another palette.")
    private var name = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        nameField.placeholderString = "Name this color"
        nameField.font = .systemFont(ofSize: 12)
        nameField.controlSize = .small
        nameField.delegate = self
        nameField.setAccessibilityLabel("Color name")
        valueLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        removeButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove from palette")
        removeButton.isBordered = false
        removeButton.imagePosition = .imageOnly
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.toolTip = "Remove from palette (⌫)"
        removeButton.target = self
        removeButton.action = #selector(removeClicked)
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        layOut()
        show(nil, uppercaseHex: true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ entry: PaletteColor?, uppercaseHex: Bool) {
        let views: [NSView] = [swatch, nameField, valueLabel, removeButton]
        views.forEach { $0.isHidden = entry == nil }
        hint.isHidden = entry != nil
        guard let entry else { return }
        swatch.color = entry.color
        swatch.name = entry.name
        name = entry.name ?? ""
        if nameField.currentEditor() == nil {
            nameField.stringValue = name
        }
        valueLabel.stringValue = entry.color.hex(uppercase: uppercaseHex, includesAlpha: !entry.color.isOpaque)
    }

    /// Puts the keyboard in the name field, while the panel is on screen.
    func beginNaming() {
        guard let window, window.isVisible else { return }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nameField)
    }

    func controlTextDidEndEditing(_: Notification) {
        if nameField.stringValue != name {
            onRename?(nameField.stringValue)
        }
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        nameField.stringValue = name
        window?.makeFirstResponder(nil)
        return true
    }

    @objc private func removeClicked() {
        onRemove?()
    }

    private func layOut() {
        for view in [swatch, nameField, valueLabel, removeButton, hint] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 34),
            swatch.leadingAnchor.constraint(equalTo: leadingAnchor),
            swatch.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameField.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 10),
            nameField.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: nameField.trailingAnchor, constant: 10),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 8),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            removeButton.widthAnchor.constraint(equalToConstant: 24),
            hint.leadingAnchor.constraint(equalTo: leadingAnchor),
            hint.trailingAnchor.constraint(equalTo: trailingAnchor),
            hint.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}
