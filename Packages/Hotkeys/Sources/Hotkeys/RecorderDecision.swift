import OrielCore

/// What `ShortcutRecorderView` does with a key typed while it records (PLAN §7.1.4): Esc cancels, Delete clears,
/// a reserved combination is refused with the reason, and anything else is taken, flagged when another Oriel
/// shortcut already uses it.
public enum RecorderDecision: Equatable, Sendable {
    /// Plain Esc: stop recording and keep the current shortcut.
    case cancel
    /// Plain Delete or Forward Delete: remove the shortcut.
    case clear
    /// The combination is reserved; `reason` is shown to the user.
    case refuse(reason: String)
    /// The combination becomes the shortcut; `conflict` names what else uses it.
    case accept(KeyCombo, conflict: String?)

    /// - Parameters:
    ///   - allowed: reserved combinations this recorder accepts anyway (⌘⇥ for the switcher).
    ///   - inUse: other shortcuts in use, by what they do.
    public init(keyCode: UInt16, modifiers: KeyCombo.Modifiers, allowed: Set<KeyCombo>, inUse: [KeyCombo: String]) {
        switch keyCode {
        case KeyCode.escape where modifiers.isEmpty:
            self = .cancel
            return
        case KeyCode.delete where modifiers.isEmpty, KeyCode.forwardDelete where modifiers.isEmpty:
            self = .clear
            return
        default:
            break
        }
        let candidate = KeyCombo(keyCode: keyCode, modifiers: modifiers)
        if let reason = ReservedShortcuts.reason(for: candidate, allowing: allowed) {
            self = .refuse(reason: reason)
        } else {
            self = .accept(candidate, conflict: inUse[candidate])
        }
    }
}
