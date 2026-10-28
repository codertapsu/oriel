import CoreGraphics
import Foundation

/// A straight line between two points, in image space, with round caps.
nonisolated struct Line: Codable, Sendable, Equatable {
    var id: UUID
    var start: CGPoint
    var end: CGPoint
    var color: RGBAColor
    var width: CGFloat

    init(id: UUID = UUID(), start: CGPoint, end: CGPoint, color: RGBAColor, width: CGFloat) {
        self.id = id
        self.start = start
        self.end = end
        self.color = color
        self.width = width
    }
}
