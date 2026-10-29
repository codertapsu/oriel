import AppKit

/// The small label that follows the pointer over a chart: the item's name, size and share of the folder shown.
final class ChartTip: NSView {
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let background = NSVisualEffectView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        background.material = .toolTip
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 7
        background.layer?.masksToBounds = true
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.lineBreakMode = .byTruncatingMiddle
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [title, detail])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 9, bottom: 6, right: 9)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            title.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            detail.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
        ])
        isHidden = true
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows the tip near `point` (in the superview), kept inside it.
    func show(title text: String, detail: String, near point: CGPoint) {
        title.stringValue = text
        self.detail.stringValue = detail
        let size = fittingSize
        guard let container = superview?.bounds else { return }
        var origin = CGPoint(x: point.x + 14, y: point.y + 16)
        if origin.x + size.width > container.maxX - 4 {
            origin.x = point.x - size.width - 10
        }
        if origin.y + size.height > container.maxY - 4 {
            origin.y = point.y - size.height - 10
        }
        frame = CGRect(origin: CGPoint(x: max(4, origin.x), y: max(4, origin.y)), size: size)
        isHidden = false
    }

    func hide() {
        isHidden = true
    }

    override var isFlipped: Bool {
        true
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }
}
