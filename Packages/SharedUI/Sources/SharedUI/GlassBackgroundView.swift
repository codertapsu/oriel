import AppKit

/// The background of every floating surface: untinted Liquid Glass, or an opaque window-background fill with a
/// 1 px separator when Reduce Transparency or Increase Contrast is on. It switches live and never relies on the
/// glass view to adapt by itself (PLAN §10.2). Put content in `contentView`.
public final class GlassBackgroundView: NSView {
    /// Lay subviews out in here.
    public let contentView = NSView()
    public var cornerRadius: CGFloat {
        didSet { applyStyle() }
    }

    private var glass: NSGlassEffectView?
    private var observation: NSObjectProtocol?

    public init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        contentView.translatesAutoresizingMaskIntoConstraints = false
        applyStyle()
        observation = AccessibilityDisplay.observe { [weak self] _ in self?.applyStyle() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func applyStyle() {
        contentView.removeFromSuperview()
        glass?.removeFromSuperview()
        glass = nil
        let options = AccessibilityDisplay.current
        if options.allowsGlass {
            let glass = NSGlassEffectView()
            glass.cornerRadius = cornerRadius
            glass.contentView = contentView
            pin(glass)
            self.glass = glass
            layer?.backgroundColor = nil
            layer?.borderWidth = 0
        } else {
            pin(contentView)
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1
        }
        layer?.cornerRadius = cornerRadius
        layer?.masksToBounds = !options.allowsGlass
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
