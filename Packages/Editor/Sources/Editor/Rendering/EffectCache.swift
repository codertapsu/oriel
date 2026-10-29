import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

/// Blur, pixelate, drop-shadow and background-picture images, computed with Core Image and cached by everything they
/// depend on, and the edge colour of the image for the background's inset.
///
/// Effects are always computed from the base image, which never changes, so a cached region stays valid until
/// the region or its strength changes. The cache holds a bounded number of pixels and drops the least recently
/// used entries first.
final class EffectCache {
    /// A computed image and where it goes: image space for effects, card-relative points for shadows.
    struct Output {
        let image: CGImage
        let rect: CGRect
    }

    private struct Key: Hashable {
        let kind: String
        /// The image an effect was computed from; nil for shadows, which depend on geometry only.
        let imageID: UUID?
        let x: Int
        let y: Int
        let width: Int
        let height: Int
        let amount: Int
    }

    private struct EdgeKey: Hashable {
        let imageID: UUID
        let rect: PixelRect
    }

    /// The longest side a background picture is rendered at; a canvas larger than that stretches it a little.
    static let maximumBackgroundPixels = 4096

    private let context = CIContext(options: [.cacheIntermediates: false])
    private let pixelBudget: Int
    private var entries: [Key: Output] = [:]
    private var order: [Key] = []
    private var edgeColors: [EdgeKey: RGBAColor] = [:]

    /// - Parameter pixelBudget: how many pixels the cached images may hold together (4 bytes each).
    init(pixelBudget: Int = 16_000_000) {
        self.pixelBudget = pixelBudget
    }

    var count: Int {
        entries.count
    }

    func removeAll() {
        entries.removeAll()
        order.removeAll()
        edgeColors.removeAll()
    }

    /// `region` of `base`, blurred or pixelated, clipped to the image. Nil for other kinds or an empty region.
    func effect(_ kind: AnnotationKind, region: Region, base: ImageRef) -> Output? {
        guard kind == .blur || kind == .pixelate else { return nil }
        let visible = region.rect.standardized.intersection(base.bounds)
        guard !visible.isNull, visible.width > 0, visible.height > 0 else { return nil }
        let scale = base.scale
        let minX = (visible.minX * scale).rounded(.down), minY = (visible.minY * scale).rounded(.down)
        let maxX = (visible.maxX * scale).rounded(.up), maxY = (visible.maxY * scale).rounded(.up)
        let pixels = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        let amount = max(1, (region.amount * scale).rounded())
        let key = Key(
            kind: kind.rawValue, imageID: base.id, x: Int(minX), y: Int(minY),
            width: Int(pixels.width), height: Int(pixels.height), amount: Int(amount)
        )
        if let cached = lookUp(key) {
            return cached
        }
        // Core Image's origin is bottom-left.
        let extent = CGRect(x: pixels.minX, y: CGFloat(base.image.height) - pixels.maxY, width: pixels.width, height: pixels.height)
        guard let filtered = Self.filtered(CIImage(cgImage: base.image), kind: kind, extent: extent, amount: amount),
              let image = context.createCGImage(filtered, from: extent, format: .RGBA8, colorSpace: Self.outputColorSpace(for: base.image))
        else { return nil }
        let rect = CGRect(x: pixels.minX / scale, y: pixels.minY / scale, width: pixels.width / scale, height: pixels.height / scale)
        return store(Output(image: image, rect: rect), for: key)
    }

    /// A soft black rounded rect of `size` (points), blurred by `blur` points. Its `rect` is relative to the card's
    /// top-left corner and larger than the card by the blur's reach. The mask has one pixel per point, or fewer for a
    /// card so large that it would not fit a quarter of the cache: a shadow is soft, so that never shows.
    func shadow(size: CGSize, cornerRadius: CGFloat, blur: CGFloat) -> Output? {
        let margin = (blur * 3).rounded(.up)
        let full = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)
        guard full.width >= 1, full.height >= 1 else { return nil }
        let reduction = min(1, (Double(pixelBudget / 4) / Double(full.width * full.height)).squareRoot())
        let width = max(1, Int((full.width * reduction).rounded(.up)))
        let height = max(1, Int((full.height * reduction).rounded(.up)))
        let key = Key(
            kind: "shadow", imageID: nil, x: Int(cornerRadius.rounded()),
            y: Int(size.width.rounded()) * 100_000 + Int(size.height.rounded()),
            width: width, height: height, amount: Int(blur.rounded())
        )
        if let cached = lookUp(key) {
            return cached
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let mask = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }
        mask.scaleBy(x: reduction, y: reduction)
        let card = CGRect(x: margin, y: margin, width: size.width, height: size.height)
        mask.addPath(EditorRenderer.roundedRectPath(card, radius: cornerRadius))
        mask.setFillColor(CGColor(gray: 0, alpha: 1))
        mask.fillPath()
        guard let shape = mask.makeImage() else { return nil }
        let rect = CGRect(x: -margin, y: -margin, width: CGFloat(width) / reduction, height: CGFloat(height) / reduction)
        guard blur > 0 else {
            return store(Output(image: shape, rect: rect), for: key)
        }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = CIImage(cgImage: shape)
        filter.radius = Float(blur * reduction)
        guard let blurred = filter.outputImage?.cropped(to: bounds),
              let image = context.createCGImage(blurred, from: bounds, format: .RGBA8, colorSpace: space)
        else { return nil }
        return store(Output(image: image, rect: rect), for: key)
    }

    /// `background`'s picture covering a canvas of `pixelSize` without distortion (centred, cropped on the longer
    /// side), blurred by `blur` pixels. At most `maximumBackgroundPixels` on its longer side.
    func backgroundImage(_ background: BackgroundImage, pixelSize: CGSize, blur: CGFloat) -> CGImage? {
        let longest = max(pixelSize.width, pixelSize.height)
        guard longest >= 1 else { return nil }
        let limit = min(1, CGFloat(Self.maximumBackgroundPixels) / longest)
        let width = max(1, Int((pixelSize.width * limit).rounded()))
        let height = max(1, Int((pixelSize.height * limit).rounded()))
        let radius = blur * limit
        let key = Key(
            kind: "background", imageID: background.asset.id, x: 0, y: 0, width: width, height: height, amount: Int(radius.rounded())
        )
        if let cached = lookUp(key) {
            return cached.image
        }
        let target = CGRect(x: 0, y: 0, width: width, height: height)
        let source = CIImage(cgImage: background.asset.image)
        let covered = Geometry.aspectFill(background.asset.pixelSize, in: target)
        let factor = covered.width / max(source.extent.width, 1)
        let scaler = CIFilter.lanczosScaleTransform()
        scaler.inputImage = source
        scaler.scale = Float(factor)
        scaler.aspectRatio = 1
        guard var output = scaler.outputImage else { return nil }
        output = output.transformed(by: CGAffineTransform(
            translationX: covered.minX - output.extent.minX,
            y: covered.minY - output.extent.minY
        ))
        if radius >= 0.5 {
            let blurring = CIFilter.gaussianBlur()
            blurring.inputImage = output.clampedToExtent()
            blurring.radius = Float(radius)
            guard let blurred = blurring.outputImage else { return nil }
            output = blurred
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let image = context.createCGImage(output.cropped(to: target), from: target, format: .RGBA8, colorSpace: space)
        else { return nil }
        return store(Output(image: image, rect: target), for: key).image
    }

    /// The colour of the edges of `rect` (image space) of `base`, for the background's inset.
    func edgeColor(of base: ImageRef, in rect: CGRect) -> RGBAColor? {
        let pixels = PixelRect(covering: rect, scale: base.scale).clipped(width: base.image.width, height: base.image.height)
        let key = EdgeKey(imageID: base.id, rect: pixels)
        if let cached = edgeColors[key] {
            return cached
        }
        let color = EdgeColor.estimate(base.image, in: pixels)
        if let color {
            edgeColors[key] = color
        }
        return color
    }

    // MARK: - Private

    private static func filtered(_ source: CIImage, kind: AnnotationKind, extent: CGRect, amount: CGFloat) -> CIImage? {
        switch kind {
        case .blur:
            // Clamping keeps the edges from fading to transparent; 3σ of neighbours is all a Gaussian sees.
            let filter = CIFilter.gaussianBlur()
            filter.inputImage = source.cropped(to: extent.insetBy(dx: -amount * 3, dy: -amount * 3)).clampedToExtent()
            filter.radius = Float(amount)
            return filter.outputImage?.cropped(to: extent)
        case .pixelate:
            // Blocks start at the region's top-left corner, so moving the region moves the grid with it.
            let filter = CIFilter.pixellate()
            filter.inputImage = source.cropped(to: extent).clampedToExtent()
            filter.scale = Float(amount)
            filter.center = CGPoint(x: extent.minX, y: extent.maxY)
            return filter.outputImage?.cropped(to: extent)
        default:
            return nil
        }
    }

    private static func outputColorSpace(for image: CGImage) -> CGColorSpace {
        if let space = image.colorSpace, space.model == .rgb, space.supportsOutput {
            return space
        }
        return CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }

    private func lookUp(_ key: Key) -> Output? {
        guard let output = entries[key] else { return nil }
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
        }
        order.append(key)
        return output
    }

    private func store(_ output: Output, for key: Key) -> Output {
        entries[key] = output
        order.append(key)
        var total = entries.values.reduce(0) { $0 + $1.image.width * $1.image.height }
        while total > pixelBudget, order.count > 1 {
            let oldest = order.removeFirst()
            if let removed = entries.removeValue(forKey: oldest) {
                total -= removed.image.width * removed.image.height
            }
        }
        return output
    }
}
