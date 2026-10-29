import CoreGraphics

/// A rect of whole pixels, top-left origin.
nonisolated struct PixelRect: Sendable, Hashable {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    /// The pixels `rect` (points, image space) touches at `scale` pixels per point: partial pixels count.
    init(covering rect: CGRect, scale: CGFloat) {
        let minX = Int((rect.minX * scale).rounded(.down))
        let minY = Int((rect.minY * scale).rounded(.down))
        let maxX = Int((rect.maxX * scale).rounded(.up))
        let maxY = Int((rect.maxY * scale).rounded(.up))
        self.init(x: minX, y: minY, width: max(0, maxX - minX), height: max(0, maxY - minY))
    }

    init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = max(width, 0)
        self.height = max(height, 0)
    }

    var maxX: Int {
        x + width
    }

    var maxY: Int {
        y + height
    }

    var isEmpty: Bool {
        width == 0 || height == 0
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    func insetBy(_ amount: Int) -> PixelRect {
        PixelRect(x: x + amount, y: y + amount, width: width - amount * 2, height: height - amount * 2)
    }

    /// This rect inside a `width` × `height` image.
    func clipped(width imageWidth: Int, height imageHeight: Int) -> PixelRect {
        let minX = min(max(x, 0), imageWidth), minY = min(max(y, 0), imageHeight)
        let maxX = min(max(maxX, 0), imageWidth), maxY = min(max(maxY, 0), imageHeight)
        return PixelRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Moved by `dx`, `dy`.
    func offsetBy(dx: Int, dy: Int) -> PixelRect {
        PixelRect(x: x + dx, y: y + dy, width: width, height: height)
    }
}
