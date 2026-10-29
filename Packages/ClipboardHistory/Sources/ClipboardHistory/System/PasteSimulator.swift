import CoreGraphics
import OrielCore

/// Pastes into the app in front by posting ⌘V, as if typed. macOS delivers posted keys only for an app trusted with
/// Accessibility; the caller checks that first.
enum PasteSimulator {
    static func postCommandV() {
        let key = CGKeyCode(KeyboardLayout.commandKeyCode(for: "v") ?? KeyCode.ansiV)
        let source = CGEventSource(stateID: .combinedSessionState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: isDown) else { continue }
            // Only ⌘, whatever is still held from choosing the item (⌥ for plain text would make it Paste and Match Style).
            event.flags = .maskCommand
            event.post(tap: .cghidEventTap)
        }
    }
}
