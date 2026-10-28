import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Encodes captures for AI Vision requests and history thumbnails. Off the main actor, with ImageIO only (SharedUI's
/// `ImageFile` is main-actor isolated).
enum ImageEncoder {
    struct Encoded: Sendable {
        let data: Data
        let mediaType: String

        var base64: String {
            data.base64EncodedString()
        }

        var dataURL: String {
            "data:\(mediaType);base64,\(base64)"
        }
    }

    /// The image scaled down to at most `maxDimension` pixels on its long edge, as PNG (sharp text), or as JPEG when
    /// the PNG would exceed `maxBytes`. Vision APIs downscale larger images anyway and limit request sizes.
    static func encodeForVision(_ image: CGImage, maxDimension: Int = 1568, maxBytes: Int = 3_500_000) -> Encoded? {
        let scaled = downscaled(image, maxDimension: maxDimension) ?? image
        if let png = data(scaled, type: .png), png.count <= maxBytes {
            return Encoded(data: png, mediaType: "image/png")
        }
        return data(scaled, type: .jpeg, quality: 0.85).map { Encoded(data: $0, mediaType: "image/jpeg") }
    }

    static func pngThumbnail(_ image: CGImage, maxDimension: Int = 480) -> Data? {
        data(downscaled(image, maxDimension: maxDimension) ?? image, type: .png)
    }

    static func data(_ image: CGImage, type: UTType, quality: Double? = nil) -> Data? {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else { return nil }
        let properties = quality.map { [kCGImageDestinationLossyCompressionQuality: $0] as CFDictionary }
        CGImageDestinationAddImage(destination, image, properties)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    /// Nil when the image is already small enough.
    static func downscaled(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let longEdge = max(image.width, image.height)
        guard longEdge > maxDimension, maxDimension > 0 else { return nil }
        let factor = CGFloat(maxDimension) / CGFloat(longEdge)
        let width = max(1, Int((CGFloat(image.width) * factor).rounded()))
        let height = max(1, Int((CGFloat(image.height) * factor).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
