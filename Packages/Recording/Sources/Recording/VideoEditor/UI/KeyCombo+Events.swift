import AppKit
import OrielCore

extension KeyCombo.Modifiers {
    /// The modifiers held for a key event, ignoring Caps Lock, the function key and the numeric pad.
    init(eventFlags flags: NSEvent.ModifierFlags) {
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        self = modifiers
    }
}
