import CoreGraphics

/// One window as the window server lists it (`CGWindowListCopyWindowInfo`), on any Space.
nonisolated struct ServerWindowRecord: Sendable, Hashable {
    var id: UInt32
    var pid: Int32
    var layer: Int
    /// Global CoreGraphics coordinates (points, top-left origin).
    var frame: CGRect
    var alpha: Double
    var isOnScreen: Bool
    /// `kCGWindowName`: only present with Screen Recording.
    var title: String?

    init(id: UInt32, pid: Int32, layer: Int = 0, frame: CGRect, alpha: Double = 1, isOnScreen: Bool = true, title: String? = nil) {
        self.id = id
        self.pid = pid
        self.layer = layer
        self.frame = frame
        self.alpha = alpha
        self.isOnScreen = isOnScreen
        self.title = title
    }
}
