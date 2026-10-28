import CoreGraphics
import Hotkeys
import OrielCore
import PrivateAPIs

/// Finds the system symbolic hot keys the switcher's shortcuts collide with (PLAN §7.1.4), by enumerating
/// them rather than assuming ids (on macOS 27.0.1, ⌘⇥ is id 1 and ⌘⇧⇥ id 2). Pure.
nonisolated enum CommandTabTakeover {
    /// The system app switcher's forward combination.
    static let commandTab = KeyCombo(keyCode: KeyCode.tab, modifiers: .command)
    /// Its reverse combination, which is taken over together with ⌘⇥.
    static let commandShiftTab = KeyCombo(keyCode: KeyCode.tab, modifiers: [.command, .shift])

    /// The combinations the enabled shortcuts use: forward, reverse, and ⌘⇧⇥ whenever ⌘⇥ is used.
    static func combos(for shortcuts: [ShortcutSpec]) -> Set<KeyCombo> {
        var combos = Set<KeyCombo>()
        for shortcut in shortcuts where shortcut.isEnabled && !shortcut.holdModifiers.isEmpty {
            combos.insert(shortcut.trigger)
            if let reverse = shortcut.reverseTrigger {
                combos.insert(reverse)
            }
            if shortcut.trigger == commandTab {
                combos.insert(commandShiftTab)
            }
        }
        return combos
    }

    /// Ids of the hot keys to keep disabled: those bound to a combination the shortcuts use that are on, or
    /// that we turned off ourselves. A hot key the user turned off stays theirs.
    static func hotKeyIDs(in hotKeys: [SymbolicHotKey], for shortcuts: [ShortcutSpec], disabledByUs: Set<Int32> = []) -> [Int32] {
        let wanted = combos(for: shortcuts)
        guard !wanted.isEmpty else { return [] }
        return hotKeys
            .filter { key in
                let combo = KeyCombo(
                    keyCode: key.virtualKeyCode,
                    modifiers: KeyCombo.Modifiers(cgFlags: CGEventFlags(rawValue: key.modifiers))
                )
                return wanted.contains(combo) && (key.isEnabled || disabledByUs.contains(key.id))
            }
            .map(\.id)
            .sorted()
    }

    /// Whether any enabled shortcut uses ⌘⇥ (the settings pane explains the takeover then).
    static func usesCommandTab(_ shortcuts: [ShortcutSpec]) -> Bool {
        combos(for: shortcuts).contains(commandTab)
    }
}
