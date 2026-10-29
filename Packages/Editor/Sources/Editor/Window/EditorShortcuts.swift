import AppKit
import OrielCore

/// The editor's keyboard map (PLAN §7.5), as a pure function so it can be tested without events.
///
/// Tool letters follow the characters typed (so they work on any layout); Delete, Escape, Return and the arrows
/// follow key codes. ⌘-shortcuts: ⌘Z undo, ⇧⌘Z redo, ⌘C copy image, ⌘S save `.oriel`, ⌘E export, ⌘Y Quick Look,
/// ⌘A select all, ⌘W close, ⌘= / ⌘- zoom, ⌘0 actual size, ⌘9 zoom to fit, ⇧⌘R Smart Redact.
nonisolated enum EditorShortcuts {
    /// Points an arrow key moves the selection, and with Shift.
    static let nudgeStep: CGFloat = 1
    static let largeNudgeStep: CGFloat = 10

    private static let keypadEnter: UInt16 = 76

    /// - Parameter characters: the event's `charactersIgnoringModifiers`.
    static func command(characters: String, keyCode: UInt16, modifiers: KeyCombo.Modifiers) -> EditorCommand? {
        if modifiers.contains(.command) {
            return commandKeyEquivalent(
                characters.lowercased(),
                shift: modifiers.contains(.shift),
                others: modifiers.subtracting([.command, .shift])
            )
        }
        guard !modifiers.contains(.control), !modifiers.contains(.option) else { return nil }
        let step = modifiers.contains(.shift) ? largeNudgeStep : nudgeStep
        switch keyCode {
        case KeyCode.delete, KeyCode.forwardDelete: return .delete
        case KeyCode.escape: return .cancel
        case KeyCode.returnKey, keypadEnter: return .confirm
        case KeyCode.leftArrow: return .nudge(dx: -step, dy: 0)
        case KeyCode.rightArrow: return .nudge(dx: step, dy: 0)
        case KeyCode.upArrow: return .nudge(dx: 0, dy: -step)
        case KeyCode.downArrow: return .nudge(dx: 0, dy: step)
        default: break
        }
        guard !modifiers.contains(.shift), characters.count == 1, let character = characters.lowercased().first else { return nil }
        return EditorTool.forShortcut(character).map(EditorCommand.tool)
    }

    @MainActor
    static func command(for event: NSEvent) -> EditorCommand? {
        guard event.type == .keyDown else { return nil }
        return command(
            characters: event.charactersIgnoringModifiers ?? "",
            keyCode: event.keyCode,
            modifiers: KeyCombo.Modifiers(modifierFlags: event.modifierFlags)
        )
    }

    private static func commandKeyEquivalent(_ key: String, shift: Bool, others: KeyCombo.Modifiers) -> EditorCommand? {
        guard others.isEmpty else { return nil }
        switch key {
        case "z": return shift ? .redo : .undo
        case "=", "+": return .zoomIn
        case "-": return .zoomOut
        case "r" where shift: return .smartRedact
        default: break
        }
        guard !shift else { return nil }
        switch key {
        case "c": return .copy
        case "s": return .save
        case "e": return .export
        case "y": return .quickLook
        case "a": return .selectAll
        case "w": return .close
        case "0": return .actualSize
        case "9": return .zoomToFit
        default: return nil
        }
    }
}
