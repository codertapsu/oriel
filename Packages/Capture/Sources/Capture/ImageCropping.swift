import CoreGraphics

/// Cropping and composing captured images in pixel space (PLAN §7.2, item 5).
nonisolated enum ImageCropping {
    /// The pixels of `image` inside `pixelRect` (top-left origin), copied into their own buffer so the full display
    /// image they came from can be freed.
    static func crop(_ image: CGImage, to pixelRect: CGRect) -> CGImage? {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let rect = pixelRect.integral.intersection(bounds)
        guard !rect.isNull, rect.width >= 1, rect.height >= 1 else { return nil }
        if rect == bounds {
            return image
        }
        guard let cropped = image.cropping(to: rect) else { return nil }
        return detachedCopy(of: cropped)
    }

    /// A copy of `image` that owns its pixels (a cropped `CGImage` keeps its parent's whole buffer alive).
    static func detachedCopy(of image: CGImage) -> CGImage? {
        guard let context = makeContext(like: image, width: image.width, height: image.height) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    /// One image of several displays: each image drawn at its placement, at the composite's scale. Areas no display
    /// covers stay transparent.
    static func compose(_ images: [CGImage], layout: CaptureGeometry.Composite) -> CGImage? {
        guard let first = images.first, images.count == layout.placements.count else { return nil }
        let width = Int(layout.pixelSize.width)
        let height = Int(layout.pixelSize.height)
        guard width > 0, height > 0,
              let context = makeContext(like: first, width: width, height: height, needsAlpha: true)
        else {
            return nil
        }
        context.interpolationQuality = .high
        for (image, placement) in zip(images, layout.placements) {
            // The context's origin is bottom-left; placements are top-left.
            let flipped = CGRect(
                x: placement.minX,
                y: CGFloat(height) - placement.maxY,
                width: placement.width,
                height: placement.height
            )
            context.draw(image, in: flipped)
        }
        return context.makeImage()
    }

    /// A bitmap context in `image`'s pixel format and colour space when Core Graphics accepts that combination,
    /// otherwise 8-bit (or, for float images, 16-bit float) RGBA.
    private static func makeContext(like image: CGImage, width: Int, height: Int, needsAlpha: Bool = false) -> CGContext? {
        let space = rgbSpace(of: image)
        let isFloat = image.bitmapInfo.contains(.floatComponents)
        let hasAlpha = ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
        let native = !needsAlpha || hasAlpha ? CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: image.bitmapInfo.rawValue
        ) : nil
        if let native {
            return native
        }
        let fallbackInfo: UInt32 = isFloat
            ? CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.floatComponents.rawValue
            | CGImageByteOrderInfo.order16Little.rawValue
            : CGImageAlphaInfo.premultipliedLast.rawValue
        return CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: isFloat ? 16 : 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: fallbackInfo
        )
    }

    private static func rgbSpace(of image: CGImage) -> CGColorSpace {
        if let space = image.colorSpace, space.model == .rgb {
            return space
        }
        let isFloat = image.bitmapInfo.contains(.floatComponents)
        let name = isFloat ? CGColorSpace.extendedSRGB : CGColorSpace.sRGB
        return CGColorSpace(name: name) ?? CGColorSpaceCreateDeviceRGB()
    }
}
