import AppKit
import OrielCore
import SharedUI

/// Menu items for `AppAction`s and `ToolCommand`s, with their global shortcut shown as the key equivalent.
enum ActionMenuItemFactory {
    static func make(
        _ title: String,
        symbol: String? = nil,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        handler: @escaping @MainActor @Sendable () -> Void
    ) -> NSMenuItem {
        ActionMenuItem(title, symbol: symbol, key: key, modifiers: modifiers, handler: handler)
    }

    static func make(_ action: AppAction, shortcut: KeyCombo?, handler: @escaping @MainActor @Sendable () -> Void) -> NSMenuItem {
        let item = withShortcut(ActionMenuItem(action.title, symbol: action.symbol, handler: handler), shortcut)
        ProMenuBadge.apply(action.proFeature, to: item)
        return item
    }

    static func make(_ command: ToolCommand, shortcut: KeyCombo?) -> NSMenuItem {
        let item = withShortcut(ActionMenuItem(command.title, symbol: command.symbol, handler: command.perform), shortcut)
        ProMenuBadge.apply(command.proFeature, to: item)
        return item
    }

    private static func withShortcut(_ item: NSMenuItem, _ shortcut: KeyCombo?) -> NSMenuItem {
        if let shortcut, let character = keyEquivalent(for: shortcut.keyCode) {
            item.keyEquivalent = character
            item.keyEquivalentModifierMask = modifierFlags(shortcut.modifiers)
        }
        return item
    }

    /// Only plain letter and digit keys can be shown as a menu key equivalent.
    private static func keyEquivalent(for keyCode: UInt16) -> String? {
        let name = KeyCode.name(for: keyCode)
        guard name.count == 1, let scalar = name.unicodeScalars.first, CharacterSet.alphanumerics.contains(scalar) else {
            return nil
        }
        return name.lowercased()
    }

    private static func modifierFlags(_ modifiers: KeyCombo.Modifiers) -> NSEvent.ModifierFlags {
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
}
