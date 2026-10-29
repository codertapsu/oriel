import AppKit

/// A step's thumbnail in the sequence window: the capture fitted into the view with a hairline border, and its click
/// marker where the exports put it. While the image is still being written there is a placeholder instead.
final class StepThumbnailView: NSView {
    private var thumbnail: CGImage?
    /// The full image's size in pixels, which the click is measured in.
    private var pixelSize = CGSize(width: 1, height: 1)
    private var click: CGPoint?
    private var scale: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    func show(_ thumbnail: CGImage?, pixelSize: CGSize, click: CGPoint?, scale: CGFloat) {
        self.thumbnail = thumbnail
        self.pixelSize = CGSize(width: max(pixelSize.width, 1), height: max(pixelSize.height, 1))
        self.click = click
        self.scale = max(scale, 1)
        let marked = click == nil ? "" : ", with a click marker"
        setAccessibilityLabel("Capture, \(Int(pixelSize.width)) by \(Int(pixelSize.height)) pixels\(marked)")
        needsDisplay = true
    }

    /// Where the image is drawn: fitted into the bounds, never larger than its own size in points.
    var imageRect: CGRect {
        let points = CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
        let factor = min(1, bounds.width / points.width, bounds.height / points.height)
        let size = CGSize(width: (points.width * factor).rounded(), height: (points.height * factor).rounded())
        return CGRect(
            x: (bounds.midX - size.width / 2).rounded(),
            y: (bounds.midY - size.height / 2).rounded(),
            width: size.width,
            height: size.height
        )
    }

    override func draw(_: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let rect = imageRect
        let shape = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        if let thumbnail {
            context.saveGState()
            shape.addClip()
            // Flipped view: draw the image the right way up.
            context.translateBy(x: 0, y: rect.maxY + rect.minY)
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(thumbnail, in: rect)
            context.restoreGState()
        } else {
            NSColor.quaternaryLabelColor.setFill()
            shape.fill()
            if let symbol = NSImage(systemSymbolName: "photo", accessibilityDescription: nil) {
                let size = CGSize(width: 22, height: 18)
                symbol.draw(in: CGRect(
                    x: rect.midX - size.width / 2,
                    y: rect.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ))
            }
        }
        NSColor.separatorColor.setStroke()
        shape.lineWidth = 1
        shape.stroke()
        drawMarker(in: rect)
    }

    private func drawMarker(in rect: CGRect) {
        guard let click else { return }
        let center = CGPoint(x: rect.minX + click.x / pixelSize.width * rect.width, y: rect.minY + click.y / pixelSize.height * rect.height)
        let radius = max(5, ClickMarker.radius * scale * rect.width / pixelSize.width)
        let ring = NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        NSColor.systemRed.withAlphaComponent(0.22).setFill()
        ring.fill()
        NSColor.white.withAlphaComponent(0.9).setStroke()
        ring.lineWidth = 3
        ring.stroke()
        NSColor.systemRed.setStroke()
        ring.lineWidth = 1.5
        ring.stroke()
    }
}
