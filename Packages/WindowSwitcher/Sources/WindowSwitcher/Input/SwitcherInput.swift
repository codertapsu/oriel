import OrielCore

/// What the state machine reacts to: tap events, with the typed characters already looked up, and gestures.
nonisolated enum SwitcherInput: Sendable, Equatable {
    /// `characters` is what the key types on the current layout (nil for non-text keys); it is looked up only
    /// while the switcher is open, for search.
    case keyDown(keyCode: UInt16, modifiers: KeyCombo.Modifiers, isRepeat: Bool = false, characters: String? = nil)
    case keyUp(keyCode: UInt16, modifiers: KeyCombo.Modifiers = [])
    case flagsChanged(KeyCombo.Modifiers)
    case gesture(GestureEvent)
}
