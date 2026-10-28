import CoreFoundation

/// Sticky Keys latches a modifier and releases it after the next key, so "release to switch" would fire at
/// once. The switcher forces keep-open mode while it is on (PLAN §7.1.4).
public enum StickyKeys {
    /// `stickyKey` in com.apple.universalaccess (verified on macOS 27.0.1).
    public static var isEnabled: Bool {
        CFPreferencesCopyAppValue("stickyKey" as CFString, "com.apple.universalaccess" as CFString) as? Bool ?? false
    }
}
