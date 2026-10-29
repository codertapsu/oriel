import CoreGraphics
import Foundation

/// A filled bar with round ends that stands in for a line of text (Simplify), in image space.
nonisolated struct Bar: Codable, Sendable, Equatable {
    var id: UUID
    var rect: CGRect
    var color: RGBAColor

    init(id: UUID = UUID(), rect: CGRect, color: RGBAColor) {
        self.id = id
        self.rect = rect
        self.color = color
    }

    /// Fully rounded ends, whatever the bar has been resized to.
    var cornerRadius: CGFloat {
        let standard = rect.standardized
        return min(standard.width, standard.height) / 2
    }
}
