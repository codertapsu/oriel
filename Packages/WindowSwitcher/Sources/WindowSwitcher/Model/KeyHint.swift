import OrielCore

/// One key the switcher's hint line names: what to press and what it does (PLAN §7.1.4).
nonisolated struct KeyHint: Sendable, Equatable {
    var keys: String
    var label: String

    /// The keys that act on the selected window without switching to it, like the system app switcher's Q: close,
    /// minimize, full screen and quit its app. Any of ⌘, ⌥ and ⌃ works; the line shows the ones the shortcut is held
    /// with (⌥W for ⌥⇥), or ⌥ for a shortcut held with ⇧ alone.
    static func windowActions(holding modifiers: KeyCombo.Modifiers) -> [KeyHint] {
        var held = modifiers.intersection([.control, .option, .command])
        if held.isEmpty {
            held = .option
        }
        let prefix = held.symbols
        return [
            KeyHint(keys: prefix + "W", label: "Close"),
            KeyHint(keys: prefix + "M", label: "Minimize"),
            KeyHint(keys: prefix + "F", label: "Full Screen"),
            KeyHint(keys: prefix + "Q", label: "Quit App"),
        ]
    }
}
