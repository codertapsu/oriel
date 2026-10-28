import CoreGraphics

/// A capture's pixels as 8-bit sRGB RGBA, row 0 at the top, for sampling block backgrounds.
struct PixelBuffer: Sendable {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    /// Redraws the image into a known format; nil when the image is empty or a context cannot be made.
    init?(image: CGImage) {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            // The bitmap's first row is the top of the image, so pixel (x, y) is at row y with a top-left origin.
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.init(width: width, height: height, bytes: bytes)
    }

    /// For tests: `bytes` holds `width × height` RGBA pixels, top row first.
    init(width: Int, height: Int, bytes: [UInt8]) {
        precondition(bytes.count == width * height * 4, "PixelBuffer needs width × height × 4 bytes")
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    func pixel(x: Int, y: Int) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let offset = (y * width + x) * 4
        return (bytes[offset], bytes[offset + 1], bytes[offset + 2])
    }
}
