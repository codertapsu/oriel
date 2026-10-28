import CoreGraphics
import Foundation

/// A numbered step marker: a filled circle with its number, centred on `center` in image space.
nonisolated struct Counter: Codable, Sendable, Equatable {
    var id: UUID
    var center: CGPoint
    var number: Int
    var color: RGBAColor
    var radius: CGFloat

    init(id: UUID = UUID(), center: CGPoint, number: Int, color: RGBAColor, radius: CGFloat) {
        self.id = id
        self.center = center
        self.number = number
        self.color = color
        self.radius = radius
    }

    var circleRect: CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }
}
