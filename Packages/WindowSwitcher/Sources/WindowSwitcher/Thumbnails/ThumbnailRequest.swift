import CoreGraphics

/// One tile's thumbnail, at the tile's size in pixels. Requests are served in the order given, so the caller
/// puts the visible tiles first.
nonisolated struct ThumbnailRequest: Sendable, Equatable {
    var windowID: UInt32
    var pixelSize: CGSize

    /// The largest size with the window's aspect ratio that fits `box` (both in pixels).
    static func fittedSize(window: CGSize, in box: CGSize) -> CGSize {
        guard window.width > 0, window.height > 0, box.width > 0, box.height > 0 else { return box }
        let scale = min(box.width / window.width, box.height / window.height)
        return CGSize(width: max(1, (window.width * scale).rounded()), height: max(1, (window.height * scale).rounded()))
    }
}
