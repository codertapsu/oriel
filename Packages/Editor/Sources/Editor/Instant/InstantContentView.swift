import AppKit

/// The panel's content: the editor's canvas at 1:1, inset by the outline margin, and a hairline outline around it
/// (white over a dark edge, so it shows on any screen). It also sets the tool's cursor, which a panel of an app
/// that is not active has to do through a tracking area.
final class InstantContentView: NSView {
    let canvas: EditorCanvasView
    private let margin: CGFloat

    init(canvas: EditorCanvasView, canvasSize: CGSize, margin: CGFloat) {
        self.canvas = canvas
        self.margin = margin
        super.init(frame: CGRect(x: 0, y: 0, width: canvasSize.width + margin * 2, height: canvasSize.height + margin * 2))
        canvas.frame = CGRect(x: margin, y: margin, width: canvasSize.width, height: canvasSize.height)
        addSubview(canvas)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let edge = canvas.frame
        context.setLineWidth(1)
        context.setStrokeColor(CGColor(gray: 0, alpha: 0.45))
        context.stroke(edge.insetBy(dx: -1.5, dy: -1.5))
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.9))
        context.stroke(edge.insetBy(dx: -0.5, dy: -0.5))
    }

    override func cursorUpdate(with _: NSEvent) {
        Self.cursor(for: canvas.session.tool).set()
    }

    /// The cursor each tool shows over the canvas.
    static func cursor(for tool: EditorTool) -> NSCursor {
        switch tool {
        case .select: .arrow
        case .text: .iBeam
        default: .crosshair
        }
    }
}
