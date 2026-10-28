import CoreGraphics
import Foundation

/// A rectangular area, in image space, that an effect applies to: blur, pixelate or spotlight.
nonisolated struct Region: Codable, Sendable, Equatable {
    var id: UUID
    var rect: CGRect
    /// Blur radius or pixel-block size, in points. Spotlights ignore it.
    var amount: CGFloat

    init(id: UUID = UUID(), rect: CGRect, amount: CGFloat) {
        self.id = id
        self.rect = rect
        self.amount = amount
    }

    /// Corner radius of a spotlight's lit area.
    static let spotlightCornerRadius: CGFloat = 6
}
