import AppKit

/// Whether macOS lets Oriel read what other apps copy: System Settings → Privacy & Security → Paste from Other Apps,
/// as `NSPasteboard.accessBehavior` reports it. Oriel's own copies are kept either way.
nonisolated enum ClipboardAccess: String, Sendable, Equatable {
    /// Set to Allow.
    case allowed
    /// macOS has never asked about Oriel. The next read may make it ask once, after which Oriel is listed in Paste from
    /// Other Apps; if it does not ask, reading works.
    case notAsked
    /// macOS asks before every read, so Clipboard History does not read by itself.
    case asks
    /// Set to Deny.
    case denied

    init(_ behavior: NSPasteboard.AccessBehavior) {
        switch behavior {
        case .alwaysAllow: self = .allowed
        case .alwaysDeny: self = .denied
        case .default: self = .notAsked
        case .ask: self = .asks
        @unknown default: self = .asks
        }
    }

    static var current: ClipboardAccess {
        ClipboardAccess(NSPasteboard.general.accessBehavior)
    }

    /// Whether Clipboard History reads other apps' copies when it sees them.
    var readsOtherApps: Bool {
        self == .allowed || self == .notAsked
    }
}
