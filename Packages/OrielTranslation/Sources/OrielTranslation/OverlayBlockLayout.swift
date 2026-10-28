import CoreGraphics

/// Where and how one translated block is drawn over the capture, in the overlay's points (top-left origin).
struct OverlayBlockLayout: Equatable {
    let id: Int
    let text: String
    /// The fill; taller than `boxFrame` when the text did not fit at the minimum size and the box grew downward.
    let frame: CGRect
    /// The OCR box.
    let boxFrame: CGRect
    let fontSize: CGFloat
    let colors: BlockColors
    let rightToLeft: Bool

    /// Space between the fill's edge and the text.
    static let padding: CGFloat = 1.5

    /// Whether the box grew to fit the text, which the overlay marks with an expand hint.
    var isExpanded: Bool {
        frame.height > boxFrame.height + 0.5
    }

    var textRect: CGRect {
        frame.insetBy(dx: min(Self.padding, frame.width / 4), dy: min(Self.padding, frame.height / 4))
    }

    /// Fits `text` into the block's box: `box` is in image pixels and `pointsPerPixel` maps it onto the overlay. The
    /// font is at most the original line height (`box` height / `lineCount`) and at least 6 pt.
    static func make(
        id: Int,
        text: String,
        box: CGRect,
        lineCount: Int,
        pointsPerPixel: CGFloat,
        colors: BlockColors,
        rightToLeft: Bool
    ) -> OverlayBlockLayout {
        let boxFrame = CGRect(
            x: box.minX * pointsPerPixel, y: box.minY * pointsPerPixel, width: box.width * pointsPerPixel,
            height: box.height * pointsPerPixel
        )
        let inset = CGSize(width: min(padding, boxFrame.width / 4), height: min(padding, boxFrame.height / 4))
        let available = CGSize(width: max(1, boxFrame.width - 2 * inset.width), height: max(1, boxFrame.height - 2 * inset.height))
        let lineHeight = boxFrame.height / CGFloat(max(1, lineCount))
        let fit = FontFitter.fit(text, in: available, maximumSize: lineHeight, rightToLeft: rightToLeft)
        var frame = boxFrame
        if !fit.fits {
            frame.size.height = max(boxFrame.height, fit.textSize.height + 2 * inset.height)
        }
        return OverlayBlockLayout(
            id: id, text: text, frame: frame, boxFrame: boxFrame, fontSize: fit.fontSize, colors: colors, rightToLeft: rightToLeft
        )
    }
}
