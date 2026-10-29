import CoreGraphics
import Foundation

/// The guides placed during one ruler session, and the distances between them: each pair of neighbouring parallel
/// guides on a display makes a gap, and the guides (or the display's edges) on either side of a position bound it.
nonisolated struct GuideSet: Sendable, Equatable {
    private(set) var guides: [Guide] = []

    @discardableResult
    mutating func add(_ orientation: Guide.Orientation, at position: CGFloat, on display: RulerDisplay) -> UUID {
        let guide = Guide(orientation: orientation, position: Self.clamped(position, orientation, on: display), displayID: display.id)
        guides.append(guide)
        return guide.id
    }

    mutating func move(_ id: UUID, to position: CGFloat, on display: RulerDisplay) {
        guard let index = guides.firstIndex(where: { $0.id == id }) else { return }
        guides[index].position = Self.clamped(position, guides[index].orientation, on: display)
    }

    mutating func remove(_ id: UUID) {
        guides.removeAll { $0.id == id }
    }

    mutating func removeAll() {
        guides = []
    }

    func guide(_ id: UUID) -> Guide? {
        guides.first { $0.id == id }
    }

    /// The guides of one orientation on a display, in order of position.
    func guides(_ orientation: Guide.Orientation, on displayID: CGDirectDisplayID) -> [Guide] {
        guides.filter { $0.orientation == orientation && $0.displayID == displayID }.sorted { $0.position < $1.position }
    }

    /// The guide nearest `point` on its display, if one is within `tolerance` points.
    func guide(near point: CGPoint, on displayID: CGDirectDisplayID, tolerance: CGFloat) -> Guide? {
        guides.filter { $0.displayID == displayID && $0.distance(to: point) <= tolerance }
            .min { $0.distance(to: point) < $1.distance(to: point) }
    }

    /// The spaces between neighbouring guides of one orientation, in order.
    func gaps(_ orientation: Guide.Orientation, on displayID: CGDirectDisplayID) -> [ClosedRange<CGFloat>] {
        let positions = guides(orientation, on: displayID).map(\.position)
        return zip(positions, positions.dropFirst()).compactMap { $0 < $1 ? $0 ... $1 : nil }
    }

    /// The nearest guides on either side of `position`, or the display's edges where there are none: the space a new
    /// guide there would split.
    func bounds(around position: CGFloat, _ orientation: Guide.Orientation, on display: RulerDisplay) -> ClosedRange<CGFloat> {
        let positions = guides(orientation, on: display.id).map(\.position)
        let edges = orientation == .vertical ? (display.frame.minX, display.frame.maxX) : (display.frame.minY, display.frame.maxY)
        let lower = positions.last { $0 < position } ?? edges.0
        let upper = positions.first { $0 > position } ?? edges.1
        return lower ... max(lower, upper)
    }

    private static func clamped(_ position: CGFloat, _ orientation: Guide.Orientation, on display: RulerDisplay) -> CGFloat {
        let frame = display.frame
        return orientation == .vertical ? min(max(position, frame.minX), frame.maxX) : min(max(position, frame.minY), frame.maxY)
    }
}
