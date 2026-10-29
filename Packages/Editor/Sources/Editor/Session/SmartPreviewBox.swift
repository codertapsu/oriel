import CoreGraphics

/// A rect the smart tools found, outlined on the canvas while their review panel is open, so the user sees what
/// Apply would change before it does.
nonisolated struct SmartPreviewBox: Sendable, Equatable {
    /// Image space.
    var rect: CGRect
    /// Whether Apply would include it (its category is switched on).
    var isIncluded: Bool
}
