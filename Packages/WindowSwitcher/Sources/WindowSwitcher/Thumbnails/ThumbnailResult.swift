import CoreGraphics

/// A thumbnail for a tile. `isFresh` is false for an image cached in an earlier session, shown at once and
/// replaced when the new capture arrives.
nonisolated struct ThumbnailResult: Sendable {
    var windowID: UInt32
    var image: CGImage
    var isFresh: Bool
}
