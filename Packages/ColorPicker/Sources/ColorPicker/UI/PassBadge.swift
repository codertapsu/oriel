import AppKit

/// Pass or fail for one WCAG criterion, said with a symbol and a word as well as a color, or a dash where WCAG sets no
/// criterion.
final class PassBadge: NSView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .medium)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let stack = NSStackView(views: [icon, label])
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `criterion` nil shows a dash. `name` is read by VoiceOver: "AA, normal text".
    func show(_ criterion: ContrastCriterion?, ratio: Double, name: String) {
        guard let criterion else {
            icon.image = nil
            icon.isHidden = true
            label.stringValue = "—"
            label.textColor = .tertiaryLabelColor
            toolTip = "WCAG has no AAA level for user-interface components"
            setAccessibilityLabel("\(name): no criterion")
            return
        }
        let passes = criterion.isMet(by: ratio)
        icon.isHidden = false
        icon.image = NSImage(systemSymbolName: passes ? "checkmark.circle.fill" : "xmark.circle.fill", accessibilityDescription: nil)
        icon.contentTintColor = passes ? .systemGreen : .systemRed
        label.stringValue = passes ? "Pass" : "Fail"
        label.textColor = .labelColor
        let needed = ColorFormatter.decimal(criterion.minimum, places: 1)
        toolTip = "Needs \(needed):1"
        setAccessibilityLabel("\(name): \(passes ? "pass" : "fail"), needs \(needed) to 1")
    }
}
