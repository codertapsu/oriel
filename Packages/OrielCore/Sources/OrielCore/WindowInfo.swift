import CoreGraphics

/// One window as the switcher and the CLI see it (`oriel windows list --json`).
public struct WindowInfo: Codable, Sendable, Hashable, Identifiable {
    /// The `CGWindowID`.
    public let id: UInt32
    public var pid: Int32
    public var appName: String
    public var bundleID: String?
    public var title: String
    /// Global CoreGraphics coordinates (points, top-left origin).
    public var frame: CGRect
    public var isMinimized: Bool
    public var isHidden: Bool
    public var isFullScreen: Bool
    public var isOnCurrentSpace: Bool
    /// 1-based index of the window's Space on its display, when SkyLight could tell.
    public var spaceIndex: Int?
    public var displayID: UInt32?

    public init(
        id: UInt32,
        pid: Int32,
        appName: String,
        bundleID: String?,
        title: String,
        frame: CGRect,
        isMinimized: Bool = false,
        isHidden: Bool = false,
        isFullScreen: Bool = false,
        isOnCurrentSpace: Bool = true,
        spaceIndex: Int? = nil,
        displayID: UInt32? = nil
    ) {
        self.id = id
        self.pid = pid
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.frame = frame
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        self.isFullScreen = isFullScreen
        self.isOnCurrentSpace = isOnCurrentSpace
        self.spaceIndex = spaceIndex
        self.displayID = displayID
    }
}
