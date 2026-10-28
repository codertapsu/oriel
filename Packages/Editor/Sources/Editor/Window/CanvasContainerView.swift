import AppKit

/// The scroll view's document view: the canvas with a margin around it, so the canvas never touches the window
/// edges. Pinch-to-zoom anywhere in it reaches `onMagnify`.
final class CanvasContainerView: NSView {
    static let margin: CGFloat = 28

    let canvas: EditorCanvasView
    /// The new zoom factor and the canvas-view point to keep under the fingers.
    var onMagnify: ((CGFloat, CGPoint) -> Void)?

    init(canvas: EditorCanvasView) {
        self.canvas = canvas
        super.init(frame: .zero)
        addSubview(canvas)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    /// Sizes the canvas to `size` (canvas points) at `zoom`, and this view to the canvas plus the margin.
    func layoutCanvas(size: CGSize, zoom: CGFloat) {
        let scaled = CGSize(width: size.width * zoom, height: size.height * zoom)
        canvas.frame = CGRect(origin: CGPoint(x: Self.margin, y: Self.margin), size: scaled)
        setFrameSize(CGSize(width: scaled.width + Self.margin * 2, height: scaled.height + Self.margin * 2))
    }

    override func magnify(with event: NSEvent) {
        onMagnify?(canvas.zoom * (1 + event.magnification), canvas.convert(event.locationInWindow, from: nil))
    }
}
