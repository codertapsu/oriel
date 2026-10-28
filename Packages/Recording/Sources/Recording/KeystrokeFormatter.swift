import AppKit
import OrielCore

/// Turns a key press into what the keystroke HUD shows: `⌘⇧4`, `⌥←`, `↩`, or the typed text. Pure.
nonisolated enum KeystrokeFormatter {
    /// One key press as the HUD shows it.
    struct Press: Equatable, Sendable {
        let label: String
        /// Plain typing, which joins the text before it; shortcuts and special keys stand alone.
        let isText: Bool
    }

    /// Keys shown by their symbol even without modifiers: Return, Tab, Delete, Esc, arrows, navigation, F-keys.
    static let specialKeys: Set<UInt16> = [
        KeyCode.returnKey, keypadEnter, KeyCode.tab, KeyCode.delete, KeyCode.escape, KeyCode.forwardDelete,
        115, 119, 116, 121, KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.downArrow, KeyCode.upArrow,
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
    ]
    static let keypadEnter: UInt16 = 76

    /// `characters` is what the key typed (`NSEvent.characters`), `baseCharacters` what it types without
    /// modifiers (`charactersIgnoringModifiers`). Shift alone does not make a shortcut.
    static func press(
        keyCode: UInt16,
        modifiers: KeyCombo.Modifiers,
        characters: String?,
        baseCharacters: String?
    ) -> Press? {
        let shortcutModifiers = modifiers.intersection([.command, .control, .option])
        let isSpecial = specialKeys.contains(keyCode)
        if shortcutModifiers.isEmpty, !isSpecial, let text = characters, isPrintable(text) {
            return Press(label: text, isText: true)
        }
        let key: String = if keyCode == keypadEnter {
            "⌅"
        } else if isSpecial || keyCode == KeyCode.space {
            KeyCode.name(for: keyCode)
        } else if let base = baseCharacters, isPrintable(base) {
            base.uppercased()
        } else {
            KeyCode.name(for: keyCode)
        }
        return Press(label: modifiers.symbols + key, isText: false)
    }

    /// AppKit's flags as Oriel's modifier set.
    static func modifiers(from flags: NSEvent.ModifierFlags) -> KeyCombo.Modifiers {
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        return modifiers
    }

    /// Text without control characters or the private-use codes AppKit gives function keys.
    static func isPrintable(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !(0xF700 ... 0xF8FF).contains(scalar.value)
        }
    }
}
