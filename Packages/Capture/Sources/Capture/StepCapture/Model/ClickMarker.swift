import CoreGraphics

/// Where a step's click marker goes (PLAN §17, Step Capture → Mark Clicks). Oriel learns where the user clicks from
/// an `NSEvent` global mouse-down monitor, which needs no permission; a capture maps that point into its image when
/// the image shows its area one to one, which every capture does except a window taken with its shadow.
nonisolated enum ClickMarker {
    /// The marker's radius, in points.
    static let radius: CGFloat = 16

    /// `click` (global CoreGraphics points) as a pixel of an image of `area` (global points) at `scale` pixels per
    /// point, top-left origin. Nil when the click is outside the area, or the image is not the area at that scale.
    /// A scrolling capture is taller than its area, and its first screenful is the area as it was.
    static func pixelPoint(of click: CGPoint, in area: CGRect, scale: CGFloat, imageSize: CGSize) -> CGPoint? {
        guard area.width > 0, area.height > 0, scale > 0, area.contains(click) else { return nil }
        let tolerance = max(2, scale)
        guard abs(imageSize.width - area.width * scale) <= tolerance, imageSize.height >= area.height * scale - tolerance else {
            return nil
        }
        return CGPoint(x: ((click.x - area.minX) * scale).rounded(), y: ((click.y - area.minY) * scale).rounded())
    }
}
