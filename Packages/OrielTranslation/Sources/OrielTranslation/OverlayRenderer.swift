import AppKit

/// Draws translated blocks: the on-screen overlay and the annotated PNG export use the same code, so the export looks
/// like what the user saw.
enum OverlayRenderer {
    /// Draws into the current `NSGraphicsContext`, which must be flipped (top-left origin, points).
    static func draw(_ layouts: [OverlayBlockLayout]) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        for layout in layouts {
            context.setFillColor(layout.colors.background.cgColor)
            context.fill(layout.frame)
            let color = NSColor(cgColor: layout.colors.text.cgColor) ?? .black
            let attributes = FontFitter.attributes(fontSize: layout.fontSize, color: color, rightToLeft: layout.rightToLeft)
            NSAttributedString(string: layout.text, attributes: attributes)
                .draw(with: layout.textRect, options: FontFitter.drawingOptions, context: nil)
            if layout.isExpanded {
                drawExpandHint(in: layout.frame, color: layout.colors.text, context: context)
            }
        }
    }

    /// A small downward chevron in the bottom-right corner: this box grew to fit its text.
    static func drawExpandHint(in frame: CGRect, color: RGBColor, context: CGContext) {
        let size = min(8, frame.width / 4)
        guard size >= 3 else { return }
        let tip = CGPoint(x: frame.maxX - size, y: frame.maxY - 2)
        context.saveGState()
        context.setStrokeColor(color.cgColor.copy(alpha: 0.7) ?? color.cgColor)
        context.setLineWidth(1.5)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: tip.x - size / 2, y: tip.y - size / 2))
        context.addLine(to: tip)
        context.addLine(to: CGPoint(x: tip.x + size / 2, y: tip.y - size / 2))
        context.strokePath()
        context.restoreGState()
    }

    /// The capture with the translations drawn over it, at the capture's full pixel size. `pointSize` is the space the
    /// layouts were made in.
    static func annotatedImage(_ image: CGImage, layouts: [OverlayBlockLayout], pointSize: CGSize) -> CGImage? {
        let width = image.width
        let height = image.height
        guard pointSize.width > 0, pointSize.height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(width) / pointSize.width, y: -CGFloat(height) / pointSize.height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        draw(layouts)
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }
}
