import AppKit

/// The line under the tiles that names the keys acting on the selected window — "⌥W Close   ⌥M Minimize   ⌥F Full
/// Screen   ⌥Q Quit App" — keys in the label color, what they do in secondary text, centered. Hidden when Settings
/// turns the hints off or nothing is listed.
final class KeyHintView: NSView {
    private let field = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        addSubview(field)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    func update(_ hints: [KeyHint]) {
        field.attributedStringValue = Self.text(for: hints)
        setAccessibilityLabel(hints.map { "\($0.keys) \($0.label)" }.joined(separator: ", "))
    }

    /// The hints as one attributed line.
    static func text(for hints: [KeyHint]) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let keys: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]
        let labels: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph,
        ]
        let text = NSMutableAttributedString()
        for (index, hint) in hints.enumerated() {
            if index > 0 {
                text.append(NSAttributedString(string: "    ", attributes: labels))
            }
            text.append(NSAttributedString(string: hint.keys, attributes: keys))
            text.append(NSAttributedString(string: " " + hint.label, attributes: labels))
        }
        return text
    }

    override func layout() {
        super.layout()
        field.frame = CGRect(x: 12, y: (bounds.height - 16) / 2 - 2, width: max(bounds.width - 24, 0), height: 16)
    }

    override func isAccessibilityElement() -> Bool {
        true
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        .staticText
    }
}
