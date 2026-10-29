import CoreGraphics

/// The desktop's icons and widgets, which Settings → Capture → Hide desktop icons and widgets leaves out of area,
/// screen and all-displays captures and of the frozen screen (PLAN §17). They are left out through the
/// ScreenCaptureKit filter, so Finder is never restarted and none of its settings change. Pure, over what
/// ScreenCaptureKit says about each window: who owns it and its window layer.
///
/// On macOS 27.0.1 Finder draws the icons in one window per display at the desktop-icon level, and Notification
/// Center draws each widget in its own window two levels above that. The wallpaper belongs to the Window Server and
/// WindowManager, below the desktop level, and stays in the picture.
nonisolated enum DesktopClutter {
    static let finder = "com.apple.finder"
    /// Notification Center, which draws the desktop widgets.
    static let widgetHost = "com.apple.notificationcenterui"

    /// From the desktop-icon level up to the backstop-menu level, below which no app window ever sits.
    static let layers = Int(CGWindowLevelForKey(.desktopIconWindow)) ..< Int(CGWindowLevelForKey(.backstopMenu))

    /// Whether a window is one of Finder's desktop-icon windows or a desktop widget. A window without a bundle ID is
    /// recognized by its owner's name; Finder's other windows, notifications and every app's windows sit higher.
    static func isIconOrWidget(bundleID: String?, ownerName: String?, layer: Int) -> Bool {
        guard layers.contains(layer) else { return false }
        if let bundleID, !bundleID.isEmpty {
            return bundleID == finder || bundleID == widgetHost
        }
        return ownerName == "Finder" || ownerName == "Notification Center"
    }
}
