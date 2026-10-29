import CoreGraphics

/// A coarse mask of one object, as Vision's instance mask gives it (at its analysis resolution, not the image's):
/// coverage 0…1 per cell, with a top-left origin. Smart Move reads it at the image's own pixels, softly, so a lifted
/// object keeps smooth edges. Pure.
nonisolated struct MaskGrid: Sendable, Equatable {
    let width: Int
    let height: Int
    /// Row-major, top row first.
    let values: [Float]

    init(width: Int, height: Int, values: [Float]) {
        self.width = width
        self.height = height
        self.values = values.count == width * height ? values : [Float](repeating: 0, count: width * height)
    }

    /// The covered cells' bounding box, in an image of `imageSize` pixels: nil when nothing is covered.
    func boundingBox(in imageSize: CGSize, threshold: Float = 0.5) -> PixelRect? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0 ..< height {
            for x in 0 ..< width where values[y * width + x] >= threshold {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY, width > 0, height > 0 else { return nil }
        let scaleX = imageSize.width / CGFloat(width), scaleY = imageSize.height / CGFloat(height)
        return PixelRect(covering: CGRect(
            x: CGFloat(minX) * scaleX,
            y: CGFloat(minY) * scaleY,
            width: CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        ), scale: 1)
    }

    /// The coverage at image pixel (`x`, `y`) of an image of `imageSize` pixels, bilinearly between cells.
    func coverage(x: Int, y: Int, in imageSize: CGSize) -> Float {
        guard width > 0, height > 0, imageSize.width > 0, imageSize.height > 0 else { return 0 }
        let gridX = (Double(x) + 0.5) * Double(width) / Double(imageSize.width) - 0.5
        let gridY = (Double(y) + 0.5) * Double(height) / Double(imageSize.height) - 0.5
        let x0 = Int(gridX.rounded(.down)), y0 = Int(gridY.rounded(.down))
        let fx = Float(gridX - Double(x0)), fy = Float(gridY - Double(y0))
        func value(_ column: Int, _ row: Int) -> Float {
            let column = min(max(column, 0), width - 1), row = min(max(row, 0), height - 1)
            return values[row * width + column]
        }
        let top = value(x0, y0) * (1 - fx) + value(x0 + 1, y0) * fx
        let bottom = value(x0, y0 + 1) * (1 - fx) + value(x0 + 1, y0 + 1) * fx
        return top * (1 - fy) + bottom * fy
    }

    /// The mask grown by one cell in every direction, so the fill under a lifted object also covers its fringe.
    func dilated() -> MaskGrid {
        var grown = values
        for y in 0 ..< height {
            for x in 0 ..< width {
                var strongest: Float = 0
                for dy in -1 ... 1 {
                    for dx in -1 ... 1 {
                        let column = x + dx, row = y + dy
                        if column >= 0, row >= 0, column < width, row < height {
                            strongest = max(strongest, values[row * width + column])
                        }
                    }
                }
                grown[y * width + x] = strongest
            }
        }
        return MaskGrid(width: width, height: height, values: grown)
    }
}
