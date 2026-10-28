import CoreGraphics
import Foundation

/// A straight arrow from `start` to the head at `end`, in image space.
nonisolated struct Arrow: Codable, Sendable, Equatable {
    var id: UUID
    var start: CGPoint
    var end: CGPoint
    var color: RGBAColor
    /// Shaft width in points; the head scales with it.
    var width: CGFloat

    init(id: UUID = UUID(), start: CGPoint, end: CGPoint, color: RGBAColor, width: CGFloat) {
        self.id = id
        self.start = start
        self.end = end
        self.color = color
        self.width = width
    }

    /// Length of the head along the shaft, never more than the arrow itself.
    var headLength: CGFloat {
        min(max(10, width * 3.5), hypot(end.x - start.x, end.y - start.y))
    }

    /// Width of the head across the shaft.
    var headWidth: CGFloat {
        max(10, width * 3.5) * 0.9
    }
}
