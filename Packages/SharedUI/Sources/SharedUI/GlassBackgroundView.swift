import AppKit

/// The background of every floating surface: untinted Liquid Glass, or an opaque window-background fill with a
/// 1 px separator when Reduce Transparency or Increase Contrast is on. It switches live and never relies on the
/// glass view to adapt by itself (PLAN §10.2). Put content in `contentView`.
public final class GlassBackgroundView: NSView {
    /// Lay subviews out in here.
    public let contentView = NSView()
    public var cornerRadius: CGFloat {
        didSet { apply(display) }
    }

    /// The options it is drawn for: the system's, followed live.
    public private(set) var display: AccessibilityDisplay

    private var glass: NSGlassEffectView?
    private var observation: NSObjectProtocol?

    public init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
        display = .current
        super.init(frame: .zero)
        wantsLayer = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        apply(display)
        observation = AccessibilityDisplay.observe { [weak self] display in self?.apply(display) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Draws glass, or the opaque fill when `display` asks for a solid background. The system's changes arrive here by
    /// themselves; tests pass options of their own.
    public func apply(_ display: AccessibilityDisplay) {
        self.display = display
        contentView.removeFromSuperview()
        glass?.removeFromSuperview()
        glass = nil
        if display.allowsGlass {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = contentView
            pin(glass)
            self.glass = glass
            layer?.borderWidth = 0
        } else {
            pin(contentView)
            layer?.borderWidth = 1
        }
        updateColors()
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = !display.allowsGlass
    }

    override public func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    /// A layer keeps the color a `cgColor` had when it was read, so the fill is resolved again for each appearance.
    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = display.allowsGlass ? nil : NSColor.windowBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    private func pin(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
