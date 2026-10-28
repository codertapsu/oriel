import OrielCore

/// One opening of the switcher, from the trigger to commit or cancel.
nonisolated struct SwitcherSession: Sendable, Equatable {
    nonisolated enum Trigger: Sendable, Equatable {
        case keyboard
        /// A three-finger swipe: lifting the fingers commits, modifiers do not matter.
        case gesture
        /// The menu item or `oriel debug open-switcher`: always keep-open.
        case programmatic
    }

    var shortcutIndex: Int
    var holdModifiers: KeyCombo.Modifiers
    /// Releasing the hold modifiers does not commit: the shortcut says so, Sticky Keys is on, or the trigger
    /// was not the keyboard.
    var keepsOpen: Bool
    var trigger: Trigger
    var selection = 0
    var query = ""
    /// Applied to the first item list: forward selects the second item (the previous window), backward the last.
    var initialDirection: SelectionDirection?

    init(
        shortcutIndex: Int,
        holdModifiers: KeyCombo.Modifiers,
        keepsOpen: Bool,
        trigger: Trigger,
        initialDirection: SelectionDirection? = .forward
    ) {
        self.shortcutIndex = shortcutIndex
        self.holdModifiers = holdModifiers
        self.keepsOpen = keepsOpen
        self.trigger = trigger
        self.initialDirection = initialDirection
    }
}
