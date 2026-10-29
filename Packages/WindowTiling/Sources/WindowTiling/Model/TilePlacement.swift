import CoreGraphics

/// Where an action puts a window, and which edges of that frame to keep when the window cannot take exactly its size: it
/// has a minimum or maximum size, or snaps to whole characters as terminals do. A left half keeps its left edge, a
/// right half its right edge, a center third its middle.
nonisolated struct TilePlacement: Sendable, Equatable {
    /// Which part of the target a window of another size lines up with, along one axis. Vertically, start is the top.
    nonisolated enum Anchor: Sendable, Equatable {
        case start
        case center
        case end
    }

    var frame: CGRect
    var horizontal: Anchor
    var vertical: Anchor

    init(frame: CGRect, horizontal: Anchor = .center, vertical: Anchor = .center) {
        self.frame = frame
        self.horizontal = horizontal
        self.vertical = vertical
    }
}
