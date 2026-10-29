import CoreGraphics

/// The focused window's attributes, read in one Accessibility round trip before it is moved.
nonisolated struct WindowSnapshot: Sendable, Equatable {
    /// `kAXSheetRole`, which is all the role is needed for.
    static let sheetRole = "AXSheet"
    static let windowRole = "AXWindow"

    var frame: CGRect
    var role: String?
    var subrole: String?
    var isFullScreen = false
    var isMinimized = false
    /// Whether `kAXPositionAttribute` and `kAXSizeAttribute` can be set.
    var canMove = true
    var canResize = true

    /// Why the window must be left alone, if it must. A window that can move but not resize is still placed: it keeps
    /// its size and lines up with the layout's edges.
    var skipReason: TilingOutcome.SkipReason? {
        if isFullScreen {
            return .fullScreen
        }
        if role == Self.sheetRole {
            return .sheet
        }
        if let role, role != Self.windowRole {
            return .notMovable
        }
        return canMove ? nil : .notMovable
    }
}
