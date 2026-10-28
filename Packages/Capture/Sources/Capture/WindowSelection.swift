import CoreGraphics

/// A window picked on the overlay without capturing it, for recording (`CaptureCoordinator.selectWindow(prompt:)`).
public nonisolated struct WindowSelection: Sendable, Equatable {
    public let windowID: CGWindowID
    /// Global CoreGraphics points when it was picked.
    public let frame: CGRect
    public let title: String?
    public let appName: String?

    /// The window `windowID`, at `frame` (global CoreGraphics points).
    public init(windowID: CGWindowID, frame: CGRect, title: String? = nil, appName: String? = nil) {
        self.windowID = windowID
        self.frame = frame
        self.title = title
        self.appName = appName
    }
}
