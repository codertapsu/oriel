import CoreServices
import OrielCore

public enum HotkeyError: Error, Sendable, Equatable {
    /// RegisterEventHotKey refused, usually because another app already owns the combination.
    case registrationFailed(KeyCombo, OSStatus)
    /// The event tap could not be created: Accessibility is not granted.
    case tapUnavailable
}
