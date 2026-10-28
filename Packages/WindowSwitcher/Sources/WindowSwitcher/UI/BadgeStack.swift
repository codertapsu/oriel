import AppKit

/// A row of badges, left to right (or right to left when `alignsRight`).
final class BadgeStack: NSView {
    var badges: [String] = [] {
        didSet {
            guard badges != oldValue else { return }
            rebuild()
        }
    }

    var style: BadgeView.Style {
        didSet { views.forEach { $0.style = style } }
    }

    var hasOutline = false {
        didSet { views.forEach { $0.hasOutline = hasOutline } }
    }

    var alignsRight = false {
        didSet { needsLayout = true }
    }

    private var views: [BadgeView] = []

    init(style: BadgeView.Style) {
        self.style = style
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    /// The width the badges need.
    var fittingWidth: CGFloat {
        views.reduce(0) { $0 + $1.intrinsicContentSize.width } + CGFloat(max(views.count - 1, 0)) * 4
    }

    override func layout() {
        super.layout()
        var x: CGFloat = alignsRight ? bounds.width - fittingWidth : 0
        for view in views {
            let size = view.intrinsicContentSize
            view.frame = CGRect(x: x, y: (bounds.height - size.height) / 2, width: size.width, height: size.height)
            view.isHidden = view.frame.minX < 0 || view.frame.maxX > bounds.width
            x += size.width + 4
        }
    }

    private func rebuild() {
        views.forEach { $0.removeFromSuperview() }
        views = badges.map { text in
            let view = BadgeView(style: style)
            view.text = text
            view.hasOutline = hasOutline
            addSubview(view)
            return view
        }
        needsLayout = true
    }

    override func isAccessibilityElement() -> Bool {
        false
    }
}
