import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Encoding images to files with ImageIO, with the display scale recorded as DPI (72 per point). Nonisolated:
/// encoding has nothing to do with the main actor, and exporters call it from background tasks.
public nonisolated enum ImageFile {
    public enum Format: String, CaseIterable, Codable, Sendable {
        case png, jpeg, heic

        public var type: UTType {
            switch self {
            case .png: .png
            case .jpeg: .jpeg
            case .heic: .heic
            }
        }

        public var fileExtension: String {
            switch self {
            case .png: "png"
            case .jpeg: "jpg"
            case .heic: "heic"
            }
        }
    }

    public static func data(for image: CGImage, format: Format, scale: CGFloat = 1, quality: Double = 0.9) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.type.identifier as CFString, 1, nil) else {
            return nil
        }
        var properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: 72 * scale,
            kCGImagePropertyDPIHeight: 72 * scale,
        ]
        if format != .png {
            properties[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    public static func write(_ image: CGImage, to url: URL, format: Format, scale: CGFloat = 1) throws {
        guard let data = data(for: image, format: format, scale: scale) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try data.write(to: url, options: .atomic)
    }

    public static func load(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
