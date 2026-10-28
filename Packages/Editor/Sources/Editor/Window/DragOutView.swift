import AppKit

/// A grip in the action bar that drags the flattened image out as a promised file (NSDraggingSource).
final class DragOutView: NSView, NSDraggingSource {
    /// Computes what to drag when a drag starts.
    var makePayload: (() -> DragPayload?)?
    /// Called when a drag ended in a drop that took the image.
    var onDelivered: (() -> Void)?

    private var mouseDownLocation: CGPoint?
    /// The promise's delegate, kept alive until the next drag: the receiver may ask for the file after the drop.
    private var promiseWriter: FilePromiseWriter?
    private let imageView = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.image = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: nil)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        toolTip = "Drag the image into another app or the Finder"
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Drag image out")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownLocation = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let start = mouseDownLocation, hypot(location.x - start.x, location.y - start.y) > 3 else { return }
        mouseDownLocation = nil
        guard let payload = makePayload?() else {
            NSSound.beep()
            return
        }
        let writer = FilePromiseWriter(data: payload.data, fileName: payload.fileName)
        promiseWriter = writer
        let provider = ImageFilePromiseProvider(fileType: payload.contentType.identifier, delegate: writer, imageData: payload.pngData)
        let item = NSDraggingItem(pasteboardWriter: provider)
        let size = Self.previewSize(for: payload.preview.size)
        item.setDraggingFrame(
            CGRect(x: location.x - size.width / 2, y: location.y - size.height / 2, width: size.width, height: size.height),
            contents: payload.preview
        )
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func mouseUp(with _: NSEvent) {
        mouseDownLocation = nil
    }

    func draggingSession(_: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation: NSDragOperation) {
        if !operation.isEmpty {
            onDelivered?()
        }
    }

    /// The drag image: the picture scaled to fit 160 points.
    static func previewSize(for size: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return CGSize(width: 64, height: 64) }
        let factor = min(160 / max(size.width, size.height), 1)
        return CGSize(width: size.width * factor, height: size.height * factor)
    }
}
