import Foundation

/// A permission Oriel can use (PLAN §8.1): the TCC services, plus macOS's pasteboard privacy, which decides whether
/// Oriel may read what other apps copy.
public enum PermissionKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case accessibility
    case screenRecording
    case microphone
    case camera
    /// Privacy & Security → Paste from Other Apps (`NSPasteboard.accessBehavior`), for Clipboard History.
    case pasteboard

    public var id: String {
        rawValue
    }

    /// The permissions this edition can use: the App Store edition's sandbox cannot be granted Accessibility (PLAN §19).
    public static var available: [PermissionKind] {
        Sandbox.isActive ? allCases.filter { $0 != .accessibility } : allCases
    }

    /// The permission's name. Its pane in System Settings can be called something else: `settingsPaneName`.
    public var displayName: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen & System Audio Recording"
        case .microphone: "Microphone"
        case .camera: "Camera"
        case .pasteboard: "Paste from Other Apps"
        }
    }

    /// What the permission unlocks, in one sentence.
    public var purpose: String {
        switch self {
        case .accessibility:
            "Lists, focuses and arranges windows, takes over Cmd-Tab, and scrolls for scrolling capture."
        case .screenRecording:
            Sandbox.isActive
                ? "Screenshots, screen recordings, text to translate and the edges Screen Ruler measures."
                : "Screenshots, screen recordings, window thumbnails in the switcher and text to translate."
        case .microphone:
            "Adds your voice to screen recordings you start."
        case .camera:
            "Shows the camera bubble in screen recordings you start."
        case .pasteboard:
            "Lets Clipboard History keep what you copy in other apps, not only Oriel's own copies."
        }
    }

    /// Whether Oriel is still useful without it: the window tools need Accessibility, and the App Store edition, which
    /// has none, is about the screen.
    public var isRequired: Bool {
        self == (Sandbox.isActive ? .screenRecording : .accessibility)
    }

    /// The name of its pane in System Settings → Privacy & Security. macOS 27 calls Accessibility "Device Control
    /// and Data Access" (docs/os-quirks.md).
    public func settingsPaneName(macOSMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> String {
        switch self {
        case .accessibility: macOSMajorVersion >= 27 ? "Device Control and Data Access" : "Accessibility"
        case .screenRecording: "Screen & System Audio Recording"
        case .microphone: "Microphone"
        case .camera: "Camera"
        case .pasteboard: "Paste from Other Apps"
        }
    }

    /// Where the permission can be changed, worded as information rather than a push to allow it (App Review
    /// Guidelines 5.1.1(iv)); shown in Settings while the permission is off, never before Oriel has asked.
    public func settingsHint(macOSMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> String {
        let pane = "System Settings → Privacy & Security → \(settingsPaneName(macOSMajorVersion: macOSMajorVersion))"
        switch self {
        case .accessibility:
            // macOS keeps one switch per bundle ID, signed by whichever copy asked first; another copy fails it.
            return "You can change this in \(pane). If Oriel is on there but still cannot use it, select it, remove it with −, "
                + "then add Oriel again with +."
        case .screenRecording:
            return "You can change this in \(pane). After a change there, choose Quit & Reopen when macOS offers it."
        case .microphone, .camera:
            return "You can change this in \(pane)."
        case .pasteboard:
            // macOS lists an app there only once it has asked about that app.
            return "You can change this in \(pane), where Oriel is listed after macOS has asked about it once."
        }
    }
}
