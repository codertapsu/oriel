import CoreGraphics

/// Where things go on the canvas: the output image is the visible part of the base image plus padding.
///
/// Image space is the base image's (points, top-left origin, uncropped). Canvas space has its origin at the
/// top-left corner of the output. The two differ by a translation only.
nonisolated struct CanvasLayout: Equatable {
    /// The image-space rect the canvas shows.
    let contentRect: CGRect
    let padding: Padding

    /// - Parameter showsUncroppedImage: the crop tool's view: the whole image, without padding or background.
    init(document: EditorDocument, showsUncroppedImage: Bool = false) {
        if showsUncroppedImage {
            contentRect = document.base.bounds
            padding = .zero
        } else {
            contentRect = document.visibleImageRect
            padding = document.canvasPadding ?? .zero
        }
    }

    var canvasSize: CGSize {
        CGSize(width: contentRect.width + padding.horizontal, height: contentRect.height + padding.vertical)
    }

    var canvasBounds: CGRect {
        CGRect(origin: .zero, size: canvasSize)
    }

    /// The image area on the canvas, in canvas space.
    var cardRect: CGRect {
        CGRect(x: padding.left, y: padding.top, width: contentRect.width, height: contentRect.height)
    }

    /// Added to an image-space point, gives its canvas-space position.
    var offset: CGVector {
        CGVector(dx: padding.left - contentRect.minX, dy: padding.top - contentRect.minY)
    }

    func canvasPoint(fromImage point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + offset.dx, y: point.y + offset.dy)
    }

    func imagePoint(fromCanvas point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - offset.dx, y: point.y - offset.dy)
    }

    func canvasRect(fromImage rect: CGRect) -> CGRect {
        rect.offsetBy(dx: offset.dx, dy: offset.dy)
    }

    /// The output's size in pixels at `scale` pixels per point.
    func pixelSize(scale: CGFloat) -> (width: Int, height: Int) {
        (max(1, Int((canvasSize.width * scale).rounded())), max(1, Int((canvasSize.height * scale).rounded())))
    }
}
