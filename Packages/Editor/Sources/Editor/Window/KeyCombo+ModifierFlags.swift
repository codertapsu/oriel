import AppKit
import OrielCore

extension KeyCombo.Modifiers {
    /// The modifier keys held during an AppKit event.
    init(modifierFlags flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.control) {
            insert(.control)
        }
        if flags.contains(.option) {
            insert(.option)
        }
        if flags.contains(.shift) {
            insert(.shift)
        }
        if flags.contains(.command) {
            insert(.command)
        }
    }
}
