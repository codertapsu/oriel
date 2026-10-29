import CoreGraphics

/// Where things go on the canvas: the output image is the visible part of the base image, inside its card (inset and
/// window frame), inside the padding, grown to the background's aspect.
///
/// Image space is the base image's (points, top-left origin, uncropped). Canvas space has its origin at the
/// top-left corner of the output. The two differ by a translation only.
nonisolated struct CanvasLayout: Equatable {
    /// The image-space rect the canvas shows.
    let contentRect: CGRect
    /// The space the user asked for around the card; an aspect can add more.
    let padding: Padding
    let inset: CGFloat
    let titleBarHeight: CGFloat
    let canvasSize: CGSize
    /// The rounded card in canvas space: the image, its inset and its title bar.
    let cardRect: CGRect
    /// Where the visible image is drawn, in canvas space.
    let imageRect: CGRect
    /// The exported size an aspect fixes in pixels, if it does.
    let fixedPixelSize: PixelSize?

    /// - Parameter showsUncroppedImage: the crop tool's view: the whole image, without padding or background.
    init(document: EditorDocument, showsUncroppedImage: Bool = false) {
        if showsUncroppedImage {
            self.init(contentRect: document.base.bounds, padding: .zero, background: nil)
        } else {
            self.init(contentRect: document.visibleImageRect, padding: document.canvasPadding ?? .zero, background: document.background)
        }
    }

    /// The layout of `contentRect` with `padding` and what `background` adds (none of it without a background).
    init(contentRect: CGRect, padding: Padding, background: BackgroundStyle?) {
        self.contentRect = contentRect
        self.padding = padding
        inset = background?.inset ?? 0
        titleBarHeight = background?.windowFrame.titleBarHeight ?? 0
        let card = CGSize(width: contentRect.width + inset * 2, height: contentRect.height + inset * 2 + titleBarHeight)
        let minimum = CGSize(width: card.width + padding.horizontal, height: card.height + padding.vertical)
        let aspect = background?.aspect ?? .auto
        canvasSize = aspect.fitting(minimum)
        let alignment = background?.alignment ?? .center
        let spare = CGSize(width: max(0, canvasSize.width - minimum.width), height: max(0, canvasSize.height - minimum.height))
        cardRect = CGRect(
            x: padding.left + spare.width * alignment.horizontal,
            y: padding.top + spare.height * alignment.vertical,
            width: card.width,
            height: card.height
        )
        imageRect = CGRect(
            x: cardRect.minX + inset,
            y: cardRect.minY + titleBarHeight + inset,
            width: contentRect.width,
            height: contentRect.height
        )
        fixedPixelSize = aspect.pixelSize
    }

    var canvasBounds: CGRect {
        CGRect(origin: .zero, size: canvasSize)
    }

    /// Added to an image-space point, gives its canvas-space position.
    var offset: CGVector {
        CGVector(dx: imageRect.minX - contentRect.minX, dy: imageRect.minY - contentRect.minY)
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

    /// Pixels per point of the exported image: the base image's own scale, or whatever gives an aspect's fixed
    /// pixel size exactly.
    func exportScale(baseScale: CGFloat) -> CGFloat {
        guard let fixed = fixedPixelSize, canvasSize.width > 0 else { return baseScale }
        return CGFloat(fixed.width) / canvasSize.width
    }

    /// The exported image's size in pixels.
    func exportPixelSize(baseScale: CGFloat) -> (width: Int, height: Int) {
        if let fixed = fixedPixelSize {
            return (fixed.width, fixed.height)
        }
        return pixelSize(scale: baseScale)
    }
}
