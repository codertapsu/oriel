import CoreGraphics

/// One window as Accessibility describes it: read in the AX actor, then only this value leaves it.
nonisolated struct AXWindowRecord: Sendable, Hashable {
    /// From `_AXUIElementGetWindow`; nil when the symbol is missing or the call failed.
    var windowID: UInt32?
    var title: String
    var role: String?
    var subrole: String?
    /// Global CoreGraphics coordinates, from `kAXPositionAttribute` and `kAXSizeAttribute`.
    var frame: CGRect?
    var isMinimized: Bool
    var isFullScreen: Bool
    /// Whether `kAXWindowsAttribute` listed the window. Windows on other Spaces are reached through a cached
    /// element or a remote token instead and are not listed.
    var isListed: Bool

    init(
        windowID: UInt32?,
        title: String,
        role: String? = "AXWindow",
        subrole: String? = "AXStandardWindow",
        frame: CGRect? = nil,
        isMinimized: Bool = false,
        isFullScreen: Bool = false,
        isListed: Bool = true
    ) {
        self.windowID = windowID
        self.title = title
        self.role = role
        self.subrole = subrole
        self.frame = frame
        self.isMinimized = isMinimized
        self.isFullScreen = isFullScreen
        self.isListed = isListed
    }
}
