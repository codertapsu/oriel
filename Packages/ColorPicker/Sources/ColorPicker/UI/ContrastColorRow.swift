import AppKit

/// One of the contrast checker's two colors: a well that takes drops, a field to type or paste a color into, and an
/// eyedropper that picks it off the screen.
final class ContrastColorRow: NSView, NSTextFieldDelegate {
    let pickButton = NSButton()
    var onColor: ((ColorValue) -> Void)?
    var onPick: (() -> Void)?

    private let titleLabel: NSTextField
    private let well = ColorWell(side: 28)
    private let field = NSTextField(string: "")
    private var shownText = ""

    init(title: String) {
        titleLabel = NSTextField(labelWithString: title)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        field.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        field.delegate = self
        field.setAccessibilityLabel("\(title) color")
        field.toolTip = "Type or paste a color, then press Return"
        well.setAccessibilityElement(true)
        well.setAccessibilityRole(.image)
        well.setAccessibilityLabel("\(title) color")
        well.onDrop = { [weak self] color in self?.onColor?(color) }
        pickButton.image = NSImage(systemSymbolName: "eyedropper", accessibilityDescription: "Pick the \(title.lowercased()) color")
        pickButton.bezelStyle = .push
        pickButton.imagePosition = .imageOnly
        pickButton.toolTip = "Pick the \(title.lowercased()) color from the screen"
        pickButton.target = self
        pickButton.action = #selector(pickClicked)
        for view in [titleLabel, well, field, pickButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.widthAnchor.constraint(equalToConstant: 76),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            well.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 4),
            well.centerYAnchor.constraint(equalTo: centerYAnchor),
            field.leadingAnchor.constraint(equalTo: well.trailingAnchor, constant: 10),
            field.centerYAnchor.constraint(equalTo: centerYAnchor),
            pickButton.leadingAnchor.constraint(equalTo: field.trailingAnchor, constant: 8),
            pickButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            pickButton.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ color: ColorValue, uppercaseHex: Bool) {
        well.color = color
        shownText = color.hex(uppercase: uppercaseHex, includesAlpha: !color.isOpaque)
        if field.currentEditor() == nil {
            field.stringValue = shownText
        }
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            guard let color = ColorParser.parse(field.stringValue) else {
                NSSound.beep()
                return true
            }
            window?.makeFirstResponder(nil)
            onColor?(color)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            field.stringValue = shownText
            window?.makeFirstResponder(nil)
            return true
        default:
            return false
        }
    }

    /// Leaving the field with a color in it applies it too.
    func controlTextDidEndEditing(_: Notification) {
        guard field.stringValue != shownText, let color = ColorParser.parse(field.stringValue) else {
            field.stringValue = shownText
            return
        }
        onColor?(color)
    }

    @objc private func pickClicked() {
        onPick?()
    }
}
