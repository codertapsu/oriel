import AppKit

/// The current color, large, with its HEX on it in black or white, whichever reads better. The HEX is a field: type or
/// paste any color Oriel reads (`#F80`, `rgb(…)`, `oklch(…)`, `Color(red:…)`) and press Return. A badge says when the
/// color is outside sRGB. Colors dropped on it, from the panel or another app, become the current color.
final class LargeSwatchView: NSView, NSTextFieldDelegate {
    let field = NSTextField(string: "")
    /// A typed or dropped color, to make the current one.
    var onColor: ((ColorValue) -> Void)?

    private var color: ColorValue?
    private var shownText = ""
    private let placeholder = NSTextField(labelWithString: "Pick a color from the screen")
    private let badge = NSTextField(labelWithString: "Outside sRGB")
    private let badgeBackground = NSView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        field.font = .monospacedSystemFont(ofSize: 22, weight: .semibold)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.placeholderString = "#RRGGBB"
        field.setAccessibilityLabel("Color value")
        field.toolTip = "Type or paste a color, then press Return"
        placeholder.font = .systemFont(ofSize: 13)
        placeholder.textColor = .secondaryLabelColor
        badge.font = .systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = .white
        badgeBackground.wantsLayer = true
        badgeBackground.layer?.cornerRadius = 9
        badgeBackground.layer?.backgroundColor = NSColor(white: 0, alpha: 0.55).cgColor
        badgeBackground.toolTip = """
        sRGB cannot show this color. HEX, RGB, HSL, HSB and CMYK give the nearest sRGB color; \
        Display P3, OKLCH and the code formats keep it exact.
        """
        badgeBackground.setAccessibilityElement(true)
        badgeBackground.setAccessibilityRole(.staticText)
        badgeBackground.setAccessibilityLabel("Outside sRGB")
        layOut()
        registerForDraggedTypes(ColorDrop.types)
        show(nil, text: "")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows `color` and its value, unless the user is typing in the field.
    func show(_ color: ColorValue?, text: String) {
        self.color = color
        shownText = text
        let editing = field.currentEditor() != nil
        if !editing {
            field.stringValue = text
        }
        let textColor = color?.legibleTextColor ?? .labelColor
        field.textColor = textColor
        (field.currentEditor() as? NSTextView)?.insertionPointColor = textColor
        placeholder.isHidden = color != nil
        let outside = color.map { !$0.isInSRGBGamut } ?? false
        badge.isHidden = !outside
        badgeBackground.isHidden = !outside
        setAccessibilityLabel(color == nil ? "No color yet" : "Current color \(text)\(outside ? ", outside sRGB" : "")")
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        if let color {
            SwatchDrawing.draw(color, in: bounds, cornerRadius: 12)
        } else {
            NSColor.quaternaryLabelColor.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12).fill()
        }
    }

    // MARK: Typing

    func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            commit()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            field.stringValue = shownText
            window?.makeFirstResponder(superview)
            return true
        default:
            return false
        }
    }

    private func commit() {
        guard let parsed = ColorParser.parse(field.stringValue) else {
            NSSound.beep()
            return
        }
        window?.makeFirstResponder(superview)
        onColor?(parsed)
    }

    // MARK: Dropping

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        ColorDrop(sender.draggingPasteboard) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let drop = ColorDrop(sender.draggingPasteboard) else { return false }
        onColor?(drop.color)
        return true
    }

    private func layOut() {
        for view in [field, placeholder, badgeBackground, badge] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            field.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 13),
            badge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            badgeBackground.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: -8),
            badgeBackground.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 8),
            badgeBackground.topAnchor.constraint(equalTo: badge.topAnchor, constant: -2),
            badgeBackground.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: 2),
        ])
    }
}
