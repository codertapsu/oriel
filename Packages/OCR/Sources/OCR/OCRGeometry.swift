import CoreGraphics

/// Conversions between Vision's normalized coordinates (0…1, origin at the bottom-left, y up) and image pixels
/// (origin at the top-left, y down), the space every `OCRBlock` uses (PLAN §7.6). Boxes are converted once, here.
public enum OCRGeometry {
    /// Absorbs floating-point noise (Vision reports 0.0333333331 for a box that starts at pixel 40 of 1200), so
    /// rounding outwards never adds a whole pixel by accident.
    private static let tolerance: CGFloat = 0.001

    /// The pixels covered by a normalized, bottom-left-origin rect, rounded outwards to whole pixels and clipped to
    /// the image. Returns `.zero` when nothing of the rect lies inside the image.
    public static func pixelRect(fromNormalized normalized: CGRect, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, !normalized.isNull, !normalized.isInfinite else { return .zero }
        let minX = (normalized.minX * imageSize.width + tolerance).rounded(.down)
        let maxX = (normalized.maxX * imageSize.width - tolerance).rounded(.up)
        let minY = ((1 - normalized.maxY) * imageSize.height + tolerance).rounded(.down)
        let maxY = ((1 - normalized.minY) * imageSize.height - tolerance).rounded(.up)
        let rect = CGRect(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
        let clipped = rect.intersection(CGRect(origin: .zero, size: imageSize))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return .zero }
        return clipped
    }

    /// The inverse of `pixelRect(fromNormalized:imageSize:)`, without rounding: a top-left pixel rect as a normalized,
    /// bottom-left-origin rect.
    public static func normalizedRect(fromPixel rect: CGRect, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        return CGRect(
            x: rect.minX / imageSize.width,
            y: 1 - rect.maxY / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
    }

    /// The smallest rect that contains all of `rects`; `.zero` for an empty list.
    public static func union(_ rects: [CGRect]) -> CGRect {
        guard let first = rects.first else { return .zero }
        return rects.dropFirst().reduce(first) { $0.union($1) }
    }
}
