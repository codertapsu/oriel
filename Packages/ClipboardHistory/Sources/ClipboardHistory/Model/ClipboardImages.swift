import CoreGraphics
import Foundation
import ImageIO

/// Sizes, thumbnails and previews of copied images, including the first page of a copied PDF.
nonisolated enum ClipboardImages {
    /// The type of the image a snapshot holds, most preferred first.
    static func preferredType(among types: [String]) -> String? {
        ClipboardTypes.images.first { types.contains($0) }
    }

    static func pixelSize(of data: Data, type: String) -> (width: Int, height: Int)? {
        if type == ClipboardTypes.pdf {
            return firstPage(of: data).map { page in
                let box = page.getBoxRect(.mediaBox)
                return (Int(box.width.rounded()), Int(box.height.rounded()))
            }
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    /// The image, at most `maxPixels` on its longer side; nil `maxPixels` keeps its size.
    static func image(from data: Data, type: String, maxPixels: Int?) -> CGImage? {
        if type == ClipboardTypes.pdf {
            return renderFirstPage(of: data, maxPixels: maxPixels ?? 2048)
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let maxPixels else { return CGImageSourceCreateImageAtIndex(source, 0, nil) }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func firstPage(of data: Data) -> CGPDFPage? {
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider) else { return nil }
        return document.page(at: 1)
    }

    /// The first page on white, scaled to `maxPixels` (never more than 4× its size).
    private static func renderFirstPage(of data: Data, maxPixels: Int) -> CGImage? {
        guard let page = firstPage(of: data), let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = min(CGFloat(maxPixels) / max(box.width, box.height), 4)
        let width = max(Int((box.width * scale).rounded()), 1)
        let height = max(Int((box.height * scale).rounded()), 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: sRGB,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }
}
