import CoreGraphics
import Foundation

/// A guide line across one display: vertical at an x, or horizontal at a y, in global points.
nonisolated struct Guide: Hashable, Sendable, Identifiable {
    enum Orientation: Sendable, Equatable {
        case vertical
        case horizontal

        var flipped: Orientation {
            self == .vertical ? .horizontal : .vertical
        }
    }

    let id: UUID
    let orientation: Orientation
    var position: CGFloat
    let displayID: CGDirectDisplayID

    init(id: UUID = UUID(), orientation: Orientation, position: CGFloat, displayID: CGDirectDisplayID) {
        self.id = id
        self.orientation = orientation
        self.position = position
        self.displayID = displayID
    }

    /// How far `point` is from the line, in points.
    func distance(to point: CGPoint) -> CGFloat {
        orientation == .vertical ? abs(point.x - position) : abs(point.y - position)
    }
}
