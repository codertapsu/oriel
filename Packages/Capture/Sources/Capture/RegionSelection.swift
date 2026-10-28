import CoreGraphics

/// An area picked on the frozen screen without capturing it, for recording and translation
/// (`CaptureCoordinator.selectRegion(prompt:)`).
public nonisolated struct RegionSelection: Sendable, Equatable {
    /// Global CoreGraphics coordinates (points, top-left origin of the primary display), inside one display and
    /// aligned to its pixel grid.
    public let rect: CGRect
    /// The display that holds `rect`.
    public let displayID: CGDirectDisplayID

    /// A region of `rect` (global CoreGraphics points) on the display `displayID`.
    public init(rect: CGRect, displayID: CGDirectDisplayID) {
        self.rect = rect
        self.displayID = displayID
    }
}
