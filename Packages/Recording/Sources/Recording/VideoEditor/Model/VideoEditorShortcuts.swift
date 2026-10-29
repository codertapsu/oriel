import OrielCore

/// The video editor's keyboard map (PLAN §17), as a pure function so it is tested without events.
///
/// Letters follow the characters typed, so they work on any keyboard layout; Space, Delete, Escape, Home, End and
/// the arrows follow key codes. Space plays or pauses; J, K and L shuttle; ← and → step a frame (⇧ for a second);
/// ↑ and ↓ jump between chapters; I and O set the trim (⌥ clears it); M adds a chapter; Z adds a zoom. ⌘Z and ⇧⌘Z
/// undo and redo, ⇧⌘C copies the frame's text, ⌘E exports, ⌘O opens, ⌘W closes, ⌘= and ⌘- zoom the timeline and
/// ⌘0 fits it.
nonisolated enum VideoEditorShortcuts {
    private static let home: UInt16 = 115
    private static let end: UInt16 = 119

    /// - Parameter characters: the event's `charactersIgnoringModifiers`.
    static func command(characters: String, keyCode: UInt16, modifiers: KeyCombo.Modifiers) -> VideoEditorCommand? {
        let key = characters.lowercased()
        if modifiers.contains(.command) {
            return commandKeyEquivalent(key, shift: modifiers.contains(.shift), others: modifiers.subtracting([.command, .shift]))
        }
        guard !modifiers.contains(.control) else { return nil }
        let shift = modifiers.contains(.shift)
        let option = modifiers.contains(.option)
        switch keyCode {
        case KeyCode.space where !option: return .playPause
        case KeyCode.leftArrow where !option: return shift ? .stepSeconds(-1) : .stepFrames(-1)
        case KeyCode.rightArrow where !option: return shift ? .stepSeconds(1) : .stepFrames(1)
        case KeyCode.upArrow where !option && !shift: return .previousChapter
        case KeyCode.downArrow where !option && !shift: return .nextChapter
        case home: return .goToStart
        case end: return .goToEnd
        case KeyCode.delete, KeyCode.forwardDelete: return .delete
        case KeyCode.escape: return .deselect
        default: break
        }
        guard !shift, key.count == 1 else { return nil }
        if option {
            switch keyCode {
            case KeyCode.ansiI: return .clearTrimStart
            case KeyCode.ansiO: return .clearTrimEnd
            default: return nil
            }
        }
        switch key {
        case "j": return .reverse
        case "k": return .stop
        case "l": return .forward
        case "i": return .setTrimStart
        case "o": return .setTrimEnd
        case "m": return .addChapter
        case "z": return .addZoom
        default: return nil
        }
    }

    private static func commandKeyEquivalent(_ key: String, shift: Bool, others: KeyCombo.Modifiers) -> VideoEditorCommand? {
        guard others.isEmpty else { return nil }
        switch (key, shift) {
        case ("z", false): return .undo
        case ("z", true): return .redo
        case ("c", true): return .copyFrameText
        case ("e", false): return .export
        case ("o", false): return .open
        case ("w", false): return .close
        case ("=", _), ("+", _): return .zoomTimelineIn
        case ("-", false): return .zoomTimelineOut
        case ("0", false): return .fitTimeline
        default: return nil
        }
    }
}
