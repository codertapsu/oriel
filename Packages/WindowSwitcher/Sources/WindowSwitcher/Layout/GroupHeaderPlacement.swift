import CoreGraphics

/// One group label in the panel: which group it names and where it goes, in content coordinates.
nonisolated struct GroupHeaderPlacement: Sendable, Equatable {
    /// An index into the session's groups.
    var group: Int
    var frame: CGRect
}
