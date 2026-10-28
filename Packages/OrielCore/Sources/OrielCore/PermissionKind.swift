import Foundation

/// A TCC permission Oriel can use (PLAN §8.1).
public enum PermissionKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case accessibility
    case screenRecording
    case microphone
    case camera

    public var id: String {
        rawValue
    }

    /// The permission's name. Its pane in System Settings can be called something else: `settingsPaneName`.
    public var displayName: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen & System Audio Recording"
        case .microphone: "Microphone"
        case .camera: "Camera"
        }
    }

    /// What the permission unlocks, in one sentence.
    public var purpose: String {
        switch self {
        case .accessibility:
            "Lists, focuses and arranges windows, takes over Cmd-Tab, and scrolls for scrolling capture."
        case .screenRecording:
            "Screenshots, screen recordings, window thumbnails in the switcher and text to translate."
        case .microphone:
            "Adds your voice to screen recordings you start."
        case .camera:
            "Shows the camera bubble in screen recordings you start."
        }
    }

    /// Whether Oriel is still useful without it.
    public var isRequired: Bool {
        self == .accessibility
    }

    /// The name of its pane in System Settings → Privacy & Security. macOS 27 calls Accessibility "Device Control
    /// and Data Access" (docs/os-quirks.md).
    public func settingsPaneName(macOSMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> String {
        switch self {
        case .accessibility: macOSMajorVersion >= 27 ? "Device Control and Data Access" : "Accessibility"
        case .screenRecording: "Screen & System Audio Recording"
        case .microphone: "Microphone"
        case .camera: "Camera"
        }
    }

    /// What to do in System Settings while the permission is missing.
    public func grantHint(macOSMajorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> String {
        let pane = "System Settings → Privacy & Security → \(settingsPaneName(macOSMajorVersion: macOSMajorVersion))"
        switch self {
        case .accessibility:
            // macOS keeps one switch per bundle ID, signed by whichever copy asked first; another copy fails it.
            return "Switch Oriel on in \(pane). Already on? Select it, remove it with −, then add Oriel again with +."
        case .screenRecording:
            return "Switch Oriel on in \(pane), then choose Quit & Reopen when macOS offers it."
        case .microphone, .camera:
            return "Switch Oriel on in \(pane)."
        }
    }
}
