import CoreFoundation

/// Read-only looks at other apps' preferences the settings pane explains (it never writes them).
nonisolated enum SystemPreferences {
    /// "When switching to an application, switch to a Space with open windows for the application"
    /// (System Settings → Desktop & Dock → Mission Control): `workspaces-auto-swoosh` in `com.apple.dock`,
    /// on when absent (verified on macOS 27.0.1). With it off, focusing a window on another Space does not
    /// switch there (PLAN §7.1.3).
    static var switchesToSpaceWithOpenWindows: Bool {
        CFPreferencesCopyAppValue("workspaces-auto-swoosh" as CFString, "com.apple.dock" as CFString) as? Bool ?? true
    }

    /// Whether the system uses three-finger horizontal swipes itself (between full-screen apps, value 2, or
    /// between pages, value 1), which competes with the switcher's swipe (PLAN §7.1.5). Value 2 on the dev
    /// Mac with the default trackpad settings (macOS 27.0.1).
    static var systemUsesThreeFingerHorizontalSwipe: Bool {
        for domain in ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"] {
            let value = CFPreferencesCopyAppValue("TrackpadThreeFingerHorizSwipeGesture" as CFString, domain as CFString)
            if let gesture = value as? Int, gesture != 0 {
                return true
            }
        }
        return false
    }
}
