import CoreGraphics
import Foundation

/// The geometry of a stroked rectangle or ellipse: the rect it fills, in image space.
nonisolated struct Box: Codable, Sendable, Equatable {
    var id: UUID
    var rect: CGRect
    var color: RGBAColor
    var width: CGFloat

    init(id: UUID = UUID(), rect: CGRect, color: RGBAColor, width: CGFloat) {
        self.id = id
        self.rect = rect
        self.color = color
        self.width = width
    }
}
