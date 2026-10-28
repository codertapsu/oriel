import AppKit

/// Shows a `CGImage` as layer contents, with no `NSImage` round-trip (PLAN §9), aspect-fit.
final class ThumbnailView: NSView {
    var image: CGImage? {
        didSet { needsDisplay = true }
    }

    /// Dims a stale preview.
    var isDimmed = false {
        didSet { needsDisplay = true }
    }

    var cornerRadius: CGFloat = 6 {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var wantsUpdateLayer: Bool {
        true
    }

    override func updateLayer() {
        guard let layer else { return }
        layer.contents = image
        layer.contentsGravity = .resizeAspect
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
        layer.opacity = isDimmed ? 0.55 : 1
    }

    override func isAccessibilityElement() -> Bool {
        false
    }
}
