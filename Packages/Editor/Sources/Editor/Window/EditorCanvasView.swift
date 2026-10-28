import AppKit
import OrielCore

/// The editing surface (PLAN §7.5): a layer-backed, flipped view that draws the document through
/// `EditorRenderer` and the selection or crop UI on top, and turns mouse and keyboard input into `EditorSession`
/// calls. Its frame is the canvas size times the zoom.
final class EditorCanvasView: NSView {
    let session: EditorSession
    /// Runs a command for a key press (the window controller handles every command).
    var commandHandler: ((EditorCommand) -> Bool)?
    /// How far, in screen points, a click may miss an item or a handle.
    static let hitSlop: CGFloat = 5

    private lazy var textOverlay = TextEditingOverlay(canvas: self)

    init(session: EditorSession) {
        self.session = session
        super.init(frame: .zero)
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Screenshot canvas")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    var zoom: CGFloat {
        session.zoom
    }

    /// The text view laid over a label being edited, if any.
    var editingTextView: NSTextView? {
        textOverlay.textView
    }

    // MARK: - Coordinates

    func imagePoint(fromView point: CGPoint) -> CGPoint {
        session.layout.imagePoint(fromCanvas: CGPoint(x: point.x / zoom, y: point.y / zoom))
    }

    func viewPoint(fromImage point: CGPoint) -> CGPoint {
        let canvas = session.layout.canvasPoint(fromImage: point)
        return CGPoint(x: canvas.x * zoom, y: canvas.y * zoom)
    }

    // MARK: - Updates

    /// Called after every session change and zoom change.
    func sessionDidChange() {
        needsDisplay = true
        textOverlay.sync()
        let count = session.document.items.count
        setAccessibilityValue(count == 1 ? "1 annotation" : "\(count) annotations")
        window?.invalidateCursorRects(for: self)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let layout = session.layout
        if showsCheckerboard {
            NSGraphicsContext.current?.patternPhase = .zero
            Self.checkerboard.setFill()
            CGRect(x: 0, y: 0, width: layout.canvasSize.width * zoom, height: layout.canvasSize.height * zoom).intersection(dirtyRect)
                .fill()
        }
        context.saveGState()
        context.scaleBy(x: zoom, y: zoom)
        EditorRenderer.draw(session.document, in: context, options: session.renderOptions, effects: session.effects)
        context.restoreGState()
        CanvasOverlay.draw(session: session, zoom: zoom, in: context)
    }

    /// Transparent parts of the output (padding without a fill, rounded corners, alpha in the image) show a
    /// checkerboard, as image editors do.
    private var showsCheckerboard: Bool {
        let document = session.document
        if session.tool == .crop {
            return document.base.hasAlpha
        }
        if document.background?.isOpaque == true {
            return false
        }
        let padded = (document.canvasPadding ?? .zero) != .zero
        return document.base.hasAlpha || padded || (document.background?.cornerRadius ?? 0) > 0
    }

    private static let checkerboard: NSColor = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            NSColor(white: 0.94, alpha: 1).setFill()
            rect.fill()
            NSColor(white: 0.82, alpha: 1).setFill()
            NSRect(x: 0, y: 0, width: 8, height: 8).fill()
            NSRect(x: 8, y: 8, width: 8, height: 8).fill()
            return true
        }
        return NSColor(patternImage: image)
    }()

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }
        session.beginGesture(
            at: imagePoint(fromView: convert(event.locationInWindow, from: nil)),
            modifiers: KeyCombo.Modifiers(modifierFlags: event.modifierFlags),
            tolerance: Self.hitSlop / zoom,
            clickCount: event.clickCount
        )
    }

    override func mouseDragged(with event: NSEvent) {
        autoscroll(with: event)
        session.continueGesture(
            to: imagePoint(fromView: convert(event.locationInWindow, from: nil)),
            modifiers: KeyCombo.Modifiers(modifierFlags: event.modifierFlags)
        )
    }

    override func mouseUp(with event: NSEvent) {
        session.continueGesture(
            to: imagePoint(fromView: convert(event.locationInWindow, from: nil)),
            modifiers: KeyCombo.Modifiers(modifierFlags: event.modifierFlags)
        )
        session.endGesture()
    }

    override func resetCursorRects() {
        let cursor: NSCursor = switch session.tool {
        case .select: .arrow
        case .text: .iBeam
        default: .crosshair
        }
        addCursorRect(visibleRect, cursor: cursor)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        if let command = EditorShortcuts.command(for: event), commandHandler?(command) == true {
            return
        }
        super.keyDown(with: event)
    }

    // MARK: - Standard actions, for an app main menu that sends them down the responder chain

    @objc func undo(_: Any?) {
        _ = commandHandler?(.undo)
    }

    @objc func redo(_: Any?) {
        _ = commandHandler?(.redo)
    }

    @objc func copy(_: Any?) {
        _ = commandHandler?(.copy)
    }

    @objc func delete(_: Any?) {
        _ = commandHandler?(.delete)
    }

    override func selectAll(_: Any?) {
        _ = commandHandler?(.selectAll)
    }

    @objc func saveDocument(_: Any?) {
        _ = commandHandler?(.save)
    }
}
