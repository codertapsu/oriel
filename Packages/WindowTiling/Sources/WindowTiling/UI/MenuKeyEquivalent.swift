import AppKit
import OrielCore

/// A shortcut as an `NSMenuItem` key equivalent, so the Window Tiling menu shows ⌃⌥← next to Left Half. Covers what
/// a menu can draw: letters, digits, punctuation, the arrows, Return, Delete, Forward Delete, Tab, Space, Escape and
/// F1–F12. Pure.
nonisolated enum MenuKeyEquivalent {
    static func make(for combo: KeyCombo) -> (key: String, modifiers: NSEvent.ModifierFlags)? {
        guard let key = character(for: combo.keyCode) else { return nil }
        return (key, flags(for: combo.modifiers))
    }

    /// The key equivalent string of a key code; nil for keys a menu cannot show.
    static func character(for keyCode: UInt16) -> String? {
        if let special = specialKeys[keyCode] {
            return String(utf16CodeUnits: [special], count: 1)
        }
        let name = KeyCode.name(for: keyCode)
        guard name.count == 1 else { return nil }
        // Lowercase: an uppercase key equivalent would add ⇧.
        return name.lowercased()
    }

    static func flags(for modifiers: KeyCombo.Modifiers) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) {
            flags.insert(.control)
        }
        if modifiers.contains(.option) {
            flags.insert(.option)
        }
        if modifiers.contains(.shift) {
            flags.insert(.shift)
        }
        if modifiers.contains(.command) {
            flags.insert(.command)
        }
        return flags
    }

    /// Keys whose key equivalent is a control character or one of AppKit's function-key characters.
    private static let specialKeys: [UInt16: unichar] = [
        KeyCode.leftArrow: unichar(NSLeftArrowFunctionKey),
        KeyCode.rightArrow: unichar(NSRightArrowFunctionKey),
        KeyCode.upArrow: unichar(NSUpArrowFunctionKey),
        KeyCode.downArrow: unichar(NSDownArrowFunctionKey),
        KeyCode.returnKey: 0x0D,
        KeyCode.tab: 0x09,
        KeyCode.space: 0x20,
        KeyCode.delete: 0x08,
        KeyCode.escape: 0x1B,
        KeyCode.forwardDelete: unichar(NSDeleteFunctionKey),
        122: unichar(NSF1FunctionKey), 120: unichar(NSF2FunctionKey), 99: unichar(NSF3FunctionKey),
        118: unichar(NSF4FunctionKey), 96: unichar(NSF5FunctionKey), 97: unichar(NSF6FunctionKey),
        98: unichar(NSF7FunctionKey), 100: unichar(NSF8FunctionKey), 101: unichar(NSF9FunctionKey),
        109: unichar(NSF10FunctionKey), 103: unichar(NSF11FunctionKey), 111: unichar(NSF12FunctionKey),
    ]
}
