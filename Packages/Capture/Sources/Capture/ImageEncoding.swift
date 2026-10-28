import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// ImageIO encoding that runs on any thread, for history, drag-out and HDR HEIC. Like SharedUI's `ImageFile` (which
/// `CaptureCoordinator.save` uses on the main actor), it records the display scale as DPI, 72 per point.
nonisolated enum ImageEncoding {
    /// PNG, JPEG or HEIC data for `image`.
    static func data(for image: CGImage, format: CaptureImageFormat, scale: CGFloat, quality: Double = 0.9) -> Data? {
        var properties = dpiProperties(scale: scale)
        if format != .png {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        return encode(image, type: format.type, properties: properties)
    }

    /// HEIC that keeps HDR as an ISO gain map: an SDR base image, brightened on HDR screens. `hdrImage` is
    /// ScreenCaptureKit's HDR output (extended sRGB, `SCScreenshotConfiguration.dynamicRange`).
    static func hdrHEICData(for hdrImage: CGImage, scale: CGFloat, quality: Double = 0.9) -> Data? {
        var properties = dpiProperties(scale: scale)
        properties[kCGImageDestinationLossyCompressionQuality] = quality
        properties[kCGImageDestinationEncodeRequest] = kCGImageDestinationEncodeToISOGainmap
        return encode(hdrImage, type: .heic, properties: properties)
    }

    /// A JPEG of `image` at most `maxPixels` on its long side, for history thumbnails.
    static func thumbnailData(for image: CGImage, maxPixels: Int, quality: Double = 0.8) -> Data? {
        guard let thumbnail = thumbnail(of: image, maxPixels: maxPixels) else { return nil }
        return encode(thumbnail, type: .jpeg, properties: [kCGImageDestinationLossyCompressionQuality: quality])
    }

    /// `image` scaled down (never up) so its long side is at most `maxPixels`, flattened onto white.
    static func thumbnail(of image: CGImage, maxPixels: Int) -> CGImage? {
        let longSide = max(image.width, image.height)
        let factor = longSide > maxPixels ? CGFloat(maxPixels) / CGFloat(longSide) : 1
        let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              )
        else {
            return nil
        }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(bounds)
        context.interpolationQuality = .high
        context.draw(image, in: bounds)
        return context.makeImage()
    }

    private static func dpiProperties(scale: CGFloat) -> [CFString: Any] {
        let dpi = 72 * max(scale, 1)
        return [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi]
    }

    private static func encode(_ image: CGImage, type: UTType, properties: [CFString: Any]) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
