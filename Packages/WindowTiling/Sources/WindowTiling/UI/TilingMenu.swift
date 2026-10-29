import AppKit
import OrielCore
import SharedUI

/// The status menu's Window Tiling submenu: every action with its picture and its current shortcut, in the groups of
/// `TilingAction.menuSections`. The status menu never activates Oriel, so the app in front, whose window the items
/// arrange, stays in front while it is open.
enum TilingMenu {
    static let title = "Window Tiling"

    /// - Parameters:
    ///   - shortcut: the user's shortcut for an action, shown as the item's key equivalent.
    ///   - hasOtherDisplays: whether Next and Previous Display can do anything; they are dimmed with one display.
    static func item(
        shortcut: (TilingAction) -> KeyCombo?,
        hasOtherDisplays: Bool,
        perform: @escaping @MainActor @Sendable (TilingAction) -> Void
    ) -> NSMenuItem {
        let menu = NSMenu(title: title)
        menu.autoenablesItems = false
        for (index, section) in TilingAction.menuSections.enumerated() {
            if index > 0 {
                menu.addItem(.separator())
            }
            for action in section {
                let item = ActionMenuItem(action.title, key: "", modifiers: []) { perform(action) }
                item.image = LayoutGlyph.image(for: action)
                if let combo = shortcut(action), let equivalent = MenuKeyEquivalent.make(for: combo) {
                    item.keyEquivalent = equivalent.key
                    item.keyEquivalentModifierMask = equivalent.modifiers
                }
                item.isEnabled = hasOtherDisplays || (action != .nextDisplay && action != .previousDisplay)
                menu.addItem(item)
            }
        }
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        root.image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: title)
        root.submenu = menu
        return root
    }
}
