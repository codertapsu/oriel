import CoreGraphics
import Foundation

/// A pen or highlighter stroke: the sampled pointer positions, in image space, drawn as a smoothed curve.
nonisolated struct FreehandPath: Codable, Sendable, Equatable {
    var id: UUID
    var points: [CGPoint]
    var color: RGBAColor
    var width: CGFloat

    init(id: UUID = UUID(), points: [CGPoint], color: RGBAColor, width: CGFloat) {
        self.id = id
        self.points = points
        self.color = color
        self.width = width
    }

    /// The box around the sampled points (without the stroke width).
    var pointBounds: CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, minY = first.y, maxX = first.x, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
