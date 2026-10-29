import CoreGraphics

/// The shape of the canvas around a padded screenshot. A ratio grows the canvas on one side until it has that
/// ratio; a pixel size does the same and also fixes the exported image's size, for the sizes social networks ask
/// for.
nonisolated enum CanvasAspect: Codable, Sendable, Hashable {
    /// The image plus its padding, whatever shape that is.
    case auto
    case ratio(width: Double, height: Double)
    /// Exported at exactly this many pixels.
    case pixels(width: Int, height: Int)

    /// Width over height, or nil for `.auto` (and for a degenerate size).
    var ratio: Double? {
        switch self {
        case .auto:
            nil
        case let .ratio(width, height):
            width > 0 && height > 0 ? width / height : nil
        case let .pixels(width, height):
            width > 0 && height > 0 ? Double(width) / Double(height) : nil
        }
    }

    /// The exact output size, for `.pixels`.
    var pixelSize: PixelSize? {
        guard case let .pixels(width, height) = self, width > 0, height > 0 else { return nil }
        return PixelSize(width: width, height: height)
    }

    /// The smallest size with this aspect that holds `size`: one side grows, the other stays.
    func fitting(_ size: CGSize) -> CGSize {
        guard let ratio, size.width > 0, size.height > 0 else { return size }
        let target = CGFloat(ratio)
        if size.width / size.height < target {
            return CGSize(width: size.height * target, height: size.height)
        }
        return CGSize(width: size.width, height: size.width / target)
    }

    /// Custom sizes stay within what an image can reasonably be.
    static let pixelRange: ClosedRange<Int> = 16 ... 16384
}

/// A size in whole pixels.
nonisolated struct PixelSize: Codable, Sendable, Hashable {
    var width: Int
    var height: Int
}
