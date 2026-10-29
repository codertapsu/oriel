import AppKit
import OrielCore

/// The video editor's window (PLAN §17). Its shortcuts work wherever the focus is, except while a title is being
/// typed, and the arrow keys stay with a focused list, slider or pop-up button, which use them themselves.
final class VideoEditorWindow: NSWindow {
    /// Runs a command; returns whether it was handled.
    var commandHandler: ((VideoEditorCommand) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        handle(event) || super.performKeyEquivalent(with: event)
    }

    /// Keys no responder took (the focus is on a button, say) still reach the editor.
    override func keyDown(with event: NSEvent) {
        if !handle(event) {
            super.keyDown(with: event)
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, !(firstResponder is NSText) else { return false }
        let command = VideoEditorShortcuts.command(
            characters: event.charactersIgnoringModifiers ?? "",
            keyCode: event.keyCode,
            modifiers: KeyCombo.Modifiers(eventFlags: event.modifierFlags)
        )
        guard let command, !(command.usesArrowKeys && Self.usesArrowKeys(firstResponder)) else { return false }
        return commandHandler?(command) == true
    }

    private static func usesArrowKeys(_ responder: NSResponder?) -> Bool {
        responder is NSTableView || responder is NSSlider || responder is NSPopUpButton || responder is NSStepper
            || responder is FocusPickerView || responder is NSSegmentedControl
    }
}
