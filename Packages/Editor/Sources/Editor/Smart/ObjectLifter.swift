import CoreGraphics

/// Cuts objects out of a base image for Smart Move, and erases areas for Simplify, without touching the base image:
/// the results are new layers (PLAN §17). Pure pixel work, run off the main thread by `SmartAnalyzer`.
nonisolated enum ObjectLifter {
    /// Pixels sampled around a hole for its fill.
    static let ring = HoleFiller.defaultRing

    /// The pixels of `rect` (image space) as a movable layer, and the fill for the hole. With `mask` (a coarse mask
    /// over the whole image), the layer keeps only the object's own pixels, with soft edges, and the fill covers
    /// only the object and its fringe.
    static func lift(_ rect: CGRect, mask: MaskGrid? = nil, from base: ImageRef, source: ImageLayer.Source) -> MovableObject? {
        guard let cut = cut(rect, from: base) else { return nil }
        var object = cut.pixels.cropped(to: cut.local)
        var filled = cut.pixels
        HoleFiller.fill(&filled, hole: cut.local, ring: ring)
        var fill = filled.cropped(to: cut.local)
        if let mask {
            let imageSize = CGSize(width: base.image.width, height: base.image.height)
            let grown = mask.dilated()
            for y in 0 ..< object.height {
                for x in 0 ..< object.width {
                    let imageX = cut.hole.x + x, imageY = cut.hole.y + y
                    object[x, y] = premultiplied(object[x, y], by: mask.coverage(x: imageX, y: imageY, in: imageSize))
                    fill[x, y] = premultiplied(fill[x, y], by: min(1, grown.coverage(x: imageX, y: imageY, in: imageSize) * 1.5))
                }
            }
        }
        guard let objectImage = object.makeImage(), let fillImage = fill.makeImage() else { return nil }
        let frame = pointRect(cut.hole, scale: base.scale)
        return MovableObject(
            layer: ImageLayer(asset: ImageAsset(image: objectImage), rect: frame, source: source),
            patch: ImageLayer(asset: ImageAsset(image: fillImage), rect: frame, source: source)
        )
    }

    /// The background estimated for `rect` (image space), as a patch that erases what was there.
    static func erase(_ rect: CGRect, from base: ImageRef, source: ImageLayer.Source) -> ImageLayer? {
        guard let cut = cut(rect, from: base) else { return nil }
        var filled = cut.pixels
        HoleFiller.fill(&filled, hole: cut.local, ring: ring)
        guard let image = filled.cropped(to: cut.local).makeImage() else { return nil }
        return ImageLayer(asset: ImageAsset(image: image), rect: pointRect(cut.hole, scale: base.scale), source: source)
    }

    /// Whether a lifted object shows anything: at least `minimumContent` of its visible pixels differ from its most
    /// common colour. Salient regions are sometimes plain background, which is not worth lifting.
    static func hasContent(_ object: MovableObject, minimumContent: Double = 0.03) -> Bool {
        guard let pixels = PixelImage(object.layer.asset.image) else { return false }
        var visible: [PixelColor] = []
        visible.reserveCapacity(pixels.width * pixels.height)
        for y in 0 ..< pixels.height {
            for x in 0 ..< pixels.width where pixels[x, y].alpha > 127 {
                visible.append(pixels[x, y])
            }
        }
        guard let dominant = ColorStatistics.dominant(visible) else { return false }
        return 1 - ColorStatistics.share(of: dominant, in: visible, tolerance: 16) >= minimumContent
    }

    /// The image's pixels inside `rect` (image space) at the base image's scale, grown by a pixel so anti-aliased
    /// edges go too.
    static func holeRect(for rect: CGRect, in base: ImageRef) -> PixelRect {
        let covering = PixelRect(covering: rect.standardized, scale: base.scale)
        return PixelRect(x: covering.x - 1, y: covering.y - 1, width: covering.width + 2, height: covering.height + 2)
            .clipped(width: base.image.width, height: base.image.height)
    }

    // MARK: - Private

    private struct Cut {
        /// The hole, in the image's pixels.
        let hole: PixelRect
        /// The hole and the ring around it, decoded.
        let pixels: PixelImage
        /// The hole within `pixels`.
        let local: PixelRect
    }

    private static func cut(_ rect: CGRect, from base: ImageRef) -> Cut? {
        let hole = holeRect(for: rect, in: base)
        guard !hole.isEmpty else { return nil }
        let region = PixelRect(x: hole.x - ring, y: hole.y - ring, width: hole.width + ring * 2, height: hole.height + ring * 2)
            .clipped(width: base.image.width, height: base.image.height)
        guard let pixels = PixelImage(base.image, region: region.cgRect) else { return nil }
        return Cut(hole: hole, pixels: pixels, local: hole.offsetBy(dx: -region.x, dy: -region.y))
    }

    private static func pointRect(_ pixels: PixelRect, scale: CGFloat) -> CGRect {
        CGRect(
            x: CGFloat(pixels.x) / scale,
            y: CGFloat(pixels.y) / scale,
            width: CGFloat(pixels.width) / scale,
            height: CGFloat(pixels.height) / scale
        )
    }

    private static func premultiplied(_ color: PixelColor, by coverage: Float) -> PixelColor {
        let alpha = Double(min(max(coverage, 0), 1))
        func scaled(_ channel: UInt8) -> UInt8 {
            UInt8((Double(channel) * alpha).rounded())
        }
        return PixelColor(red: scaled(color.red), green: scaled(color.green), blue: scaled(color.blue), alpha: scaled(color.alpha))
    }
}
