import AppKit

/// How every swatch is drawn: the color over a checkerboard where it is translucent, inside a rounded rectangle with a
/// hairline edge, so white and black swatches stay visible on any background.
enum SwatchDrawing {
    static func draw(_ color: ColorValue, in rect: CGRect, cornerRadius: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        if !color.isOpaque {
            drawCheckerboard(in: rect)
        }
        color.nsColor.setFill()
        rect.fill(using: .sourceOver)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.separatorColor.setStroke()
        let edge = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        edge.lineWidth = 1
        edge.stroke()
    }

    /// Light and dark gray squares, as image editors show transparency.
    private static func drawCheckerboard(in rect: CGRect) {
        let size: CGFloat = 5
        NSColor(white: 0.96, alpha: 1).setFill()
        rect.fill()
        NSColor(white: 0.78, alpha: 1).setFill()
        var row = 0
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX + (row.isMultiple(of: 2) ? 0 : size)
            while x < rect.maxX {
                CGRect(x: x, y: y, width: size, height: size).fill()
                x += 2 * size
            }
            y += size
            row += 1
        }
    }
}
