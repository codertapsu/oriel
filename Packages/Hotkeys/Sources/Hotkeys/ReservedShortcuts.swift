import OrielCore

/// Combinations macOS keeps for itself, which a recorder refuses unless told otherwise (PLAN §7.1.4).
public enum ReservedShortcuts {
    public static let commandTab = KeyCombo(keyCode: KeyCode.tab, modifiers: .command)

    private static let reasons: [KeyCombo: String] = [
        KeyCombo(keyCode: KeyCode.ansiQ, modifiers: .command): "⌘Q quits the front app.",
        KeyCombo(keyCode: KeyCode.space, modifiers: .command): "⌘Space opens Spotlight.",
        commandTab: "⌘⇥ is the system app switcher.",
        KeyCombo(keyCode: KeyCode.tab, modifiers: [.command, .shift]): "⌘⇧⇥ is the system app switcher.",
        KeyCombo(keyCode: KeyCode.ansiH, modifiers: .command): "⌘H hides the front app.",
        KeyCombo(keyCode: KeyCode.ansiW, modifiers: .command): "⌘W closes the front window.",
        KeyCombo(keyCode: KeyCode.ansi3, modifiers: [.command, .shift]): "⌘⇧3 is the system screenshot.",
        KeyCombo(keyCode: KeyCode.ansi4, modifiers: [.command, .shift]): "⌘⇧4 is the system screenshot.",
        KeyCombo(keyCode: KeyCode.ansi5, modifiers: [.command, .shift]): "⌘⇧5 is the system screenshot.",
    ]

    /// Why `combo` cannot be used, or nil when it can. `allowed` lists exceptions, such as ⌘⇥ for the
    /// switcher, which takes it over deliberately.
    public static func reason(for combo: KeyCombo, allowing allowed: Set<KeyCombo> = []) -> String? {
        if combo.modifiers.isEmpty, !(122 ... 122 + 30).contains(combo.keyCode) {
            return "A shortcut needs at least one modifier (function keys excepted)."
        }
        guard !allowed.contains(combo) else { return nil }
        return reasons[combo]
    }
}
