import CoreGraphics
import Foundation
import ImageIO
import OrielCore

/// Opens an image file as a base image: upright (EXIF orientation applied), decoded once, with the scale its DPI
/// records (144 DPI is a 2× capture).
enum ImageImporter {
    static func load(_ url: URL) throws -> ImageRef {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            throw OrielError.invalidArgument("“\(url.lastPathComponent)” is not an image Oriel can open.")
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let image: CGImage? = if orientation == 1 {
            CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        } else {
            // A full-size "thumbnail" is the documented way to get ImageIO to apply the orientation.
            CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: max(
                    Self.pixels(properties, kCGImagePropertyPixelWidth),
                    Self.pixels(properties, kCGImagePropertyPixelHeight)
                ),
                kCGImageSourceShouldCacheImmediately: true,
            ] as CFDictionary)
        }
        guard let image else {
            throw OrielError.invalidArgument("“\(url.lastPathComponent)” could not be decoded.")
        }
        let dpi = (properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue ?? 72
        return ImageRef(image: image, scale: min(max((dpi / 72).rounded(), 1), 4))
    }

    private static func pixels(_ properties: [CFString: Any], _ key: CFString) -> Int {
        (properties[key] as? NSNumber)?.intValue ?? 0
    }
}
