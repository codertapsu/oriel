import AppKit

/// A capture's thumbnail on a Quick Access card. Dragging it out drops a file (a file promise, so Finder, Mail and
/// chat apps all take it); a double-click opens the editor.
final class ThumbnailView: NSView, NSDraggingSource {
    var makePromise: (() -> PromisedImageFile)?
    /// Called when a drag ends; `true` when something accepted the file.
    var onDragEnded: ((PromisedImageFile, Bool) -> Void)?
    var onDoubleClick: (() -> Void)?
    private let image: CGImage
    private var mouseDownEvent: NSEvent?
    private var activePromise: PromisedImageFile?

    init(image: CGImage) {
        self.image = image
        super.init(frame: .zero)
        wantsLayer = true
        layer?.contents = image
        layer?.contentsGravity = .resizeAspect
        layer?.cornerRadius = 8
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(white: 0.5, alpha: 0.12).cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Capture thumbnail. Drag to save it somewhere.")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        if event.clickCount == 2 {
            onDoubleClick?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard activePromise == nil, let start = mouseDownEvent else { return }
        let moved = hypot(event.locationInWindow.x - start.locationInWindow.x, event.locationInWindow.y - start.locationInWindow.y)
        guard moved > 3, let promise = makePromise?() else { return }
        activePromise = promise
        let item = NSDraggingItem(pasteboardWriter: promise.makeProvider())
        // The preview keeps the capture's shape, as the thumbnail does.
        let frame = CaptureGeometry.aspectFit(CGSize(width: image.width, height: image.height), in: bounds)
        item.setDraggingFrame(frame, contents: NSImage(cgImage: image, size: frame.size))
        beginDraggingSession(with: [item], event: start, source: self)
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor _: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation: NSDragOperation) {
        guard let promise = activePromise else { return }
        activePromise = nil
        onDragEnded?(promise, !operation.isEmpty)
    }
}
