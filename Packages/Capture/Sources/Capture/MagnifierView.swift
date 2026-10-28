import AppKit

/// The 8× loupe next to the pointer (PLAN §7.2, item 4): the frozen pixels around it without interpolation, a pixel
/// grid, the centre pixel outlined, and its hex colour underneath.
final class MagnifierView: NSView {
    static let zoom: CGFloat = 8
    static let pixels = 15
    static let captionHeight: CGFloat = 24
    static let size = CGSize(width: CGFloat(pixels) * zoom, height: CGFloat(pixels) * zoom + captionHeight)

    var patch: PixelPatch? {
        didSet { needsDisplay = true }
    }

    var caption = "" {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool {
        false
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    override func draw(_: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let side = CGFloat(Self.pixels) * Self.zoom
        let loupe = CGRect(x: 0, y: Self.captionHeight, width: side, height: side)
        let outline = NSBezierPath(roundedRect: loupe.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)

        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        NSColor.black.setFill()
        loupe.fill()
        if let image = patch?.image {
            context.interpolationQuality = .none
            context.draw(image, in: loupe)
        }
        drawGrid(in: loupe)
        let middle = CGFloat(Self.pixels / 2) * Self.zoom
        let centre = CGRect(x: loupe.minX + middle, y: loupe.minY + middle, width: Self.zoom, height: Self.zoom)
        NSColor.black.setStroke()
        NSBezierPath(rect: centre.insetBy(dx: -0.5, dy: -0.5)).stroke()
        NSColor.white.setStroke()
        NSBezierPath(rect: centre.insetBy(dx: 0.5, dy: 0.5)).stroke()
        NSGraphicsContext.restoreGraphicsState()

        NSColor(white: 1, alpha: 0.9).setStroke()
        outline.lineWidth = 1.5
        outline.stroke()
        drawCaption()
    }

    private func drawGrid(in loupe: CGRect) {
        let grid = NSBezierPath()
        for index in 1 ..< Self.pixels {
            let offset = CGFloat(index) * Self.zoom
            grid.move(to: CGPoint(x: loupe.minX + offset, y: loupe.minY))
            grid.line(to: CGPoint(x: loupe.minX + offset, y: loupe.maxY))
            grid.move(to: CGPoint(x: loupe.minX, y: loupe.minY + offset))
            grid.line(to: CGPoint(x: loupe.maxX, y: loupe.minY + offset))
        }
        grid.lineWidth = 0.5
        NSColor(white: 0.5, alpha: 0.35).setStroke()
        grid.stroke()
    }

    private func drawCaption() {
        let box = CGRect(x: 0, y: 0, width: bounds.width, height: Self.captionHeight - 4)
        NSColor(white: 0, alpha: 0.78).setFill()
        NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = caption.size(withAttributes: attributes)
        caption.draw(at: CGPoint(x: box.midX - size.width / 2, y: box.midY - size.height / 2), withAttributes: attributes)
    }
}
