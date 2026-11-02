import AppKit
import OrielCore

/// The keyboard, while no field is being edited: 1…9 and 0 copy the formats in the order listed, ⌘C the default one,
/// ⌘1…⌘3 switch tabs, ⌫ removes the selected palette color, ⌘Z undoes a deletion, ⌘N makes a palette, ⌘, opens
/// Settings, and Esc or ⌘W closes the panel.
extension ColorPanelController {
    static let ansiZero: UInt16 = 29

    func keyDown(_ event: NSEvent) -> Bool {
        let flags = Self.modifiers(of: event)
        guard flags.isEmpty else { return false }
        if let number = Self.number(of: event.keyCode) {
            guard content.selectedTab == .color, let format = ColorFormat.format(forKeyNumber: number) else { return false }
            if format.isShown(for: model.current ?? .white) {
                copy(format)
            }
            return true
        }
        switch event.keyCode {
        case KeyCode.delete, KeyCode.forwardDelete:
            guard content.selectedTab == .palettes else { return false }
            removeSelectedColor()
            return true
        case KeyCode.escape:
            close()
            return true
        default:
            return false
        }
    }

    func keyEquivalent(_ event: NSEvent) -> Bool {
        guard event.type == .keyDown, Self.modifiers(of: event) == .command else { return false }
        if let number = Self.number(of: event.keyCode), let tab = ColorPanelTab(rawValue: number - 1) {
            select(tab)
            panel.makeFirstResponder(content)
            return true
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case "c":
            // Text selected in a field is copied by the field.
            guard !hasTextSelection else { return false }
            copyDefault()
        case "z":
            guard model.undoState != nil, !isEditingText else { return false }
            model.undo()
        case "n":
            newPalette(with: nil)
        case "w":
            close()
        case ",":
            close()
            openSettings?()
        default:
            return false
        }
        return true
    }

    /// The digit on a number-row key, 0…9.
    static func number(of keyCode: UInt16) -> Int? {
        if keyCode == ansiZero {
            return 0
        }
        return KeyCode.digits.firstIndex(of: keyCode).map { $0 + 1 }
    }

    private static func modifiers(of event: NSEvent) -> NSEvent.ModifierFlags {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
    }

    private var isEditingText: Bool {
        panel.firstResponder is NSTextView
    }

    private var hasTextSelection: Bool {
        guard let editor = panel.firstResponder as? NSTextView else { return false }
        return editor.selectedRange().length > 0
    }
}
