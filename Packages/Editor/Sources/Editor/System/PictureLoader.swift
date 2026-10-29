import CoreGraphics
import Foundation
import ImageIO

/// Decodes a picture for a background: upright, the primary image of a multi-image file (a dynamic desktop picture),
/// and no larger than needed. Nonisolated, so it runs off the main thread.
nonisolated enum PictureLoader {
    /// A background is rendered at most this many pixels on its longer side (`EffectCache.maximumBackgroundPixels`).
    static let maximumPixels = 4096

    static func load(_ url: URL, maximumPixels: Int = maximumPixels) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        return load(source, maximumPixels: maximumPixels)
    }

    static func load(_ data: Data, maximumPixels: Int = maximumPixels) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else { return nil }
        return load(source, maximumPixels: maximumPixels)
    }

    private static func load(_ source: CGImageSource, maximumPixels: Int) -> CGImage? {
        let index = CGImageSourceGetPrimaryImageIndex(source)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary)
    }
}
