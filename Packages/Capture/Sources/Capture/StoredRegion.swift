import CoreGraphics

/// The last captured area, kept for "Capture Previous Area".
nonisolated struct StoredRegion: Codable, Sendable, Equatable {
    /// Global CoreGraphics points.
    var rect: CGRect
    var displayID: UInt32
}
