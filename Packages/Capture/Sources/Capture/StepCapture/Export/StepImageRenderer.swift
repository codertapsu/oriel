import CoreGraphics
import Foundation
import SharedUI

/// A step's image as it is exported: the capture with its click marker drawn in, a red ring with a light fill and a
/// white edge, which reads on light and dark interfaces alike.
nonisolated enum StepImageRenderer {
    static let markerColor = CGColor(srgbRed: 1, green: 0.231, blue: 0.188, alpha: 1)

    /// The step's image from disk, with its marker; nil when the file cannot be read.
    static func image(for item: StepExportItem) -> CGImage? {
        guard let image = ImageFile.load(item.imageURL) else { return nil }
        guard let click = item.click else { return image }
        return marked(image, at: click, scale: item.scale) ?? image
    }

    /// `image` with a click marker centred on `point` (pixels, top-left origin).
    static func marked(_ image: CGImage, at point: CGPoint, scale: CGFloat) -> CGImage? {
        let width = image.width
        let height = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        drawMarker(in: context, at: CGPoint(x: point.x, y: CGFloat(height) - point.y), scale: scale)
        return context.makeImage()
    }

    /// The marker at `center` in the context's own coordinates.
    static func drawMarker(in context: CGContext, at center: CGPoint, scale: CGFloat) {
        let radius = ClickMarker.radius * scale
        let ring = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.saveGState()
        context.setFillColor(markerColor.copy(alpha: 0.22) ?? markerColor)
        context.fillEllipse(in: ring)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.9))
        context.setLineWidth(5 * scale)
        context.strokeEllipse(in: ring)
        context.setStrokeColor(markerColor)
        context.setLineWidth(3 * scale)
        context.strokeEllipse(in: ring)
        let dot = 3 * scale
        context.setFillColor(markerColor)
        context.fillEllipse(in: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2))
        context.restoreGState()
    }
}
