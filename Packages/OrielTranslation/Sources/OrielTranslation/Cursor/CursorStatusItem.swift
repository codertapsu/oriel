import AppKit

/// The menu-bar badge while Translate Under Cursor is on (PLAN §17): an icon of its own beside Oriel's, so the mode
/// is never left on unnoticed, with a menu that says what it does and turns it off. It exists only while the mode is
/// on.
@MainActor
final class CursorStatusItem: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let summary: @MainActor () -> String
    private let stop: @MainActor () -> Void

    /// `summary` describes the mode as it is ("Into Japanese with DeepL"), read each time the menu opens.
    init(summary: @escaping @MainActor () -> String, stop: @escaping @MainActor () -> Void) {
        self.summary = summary
        self.stop = stop
        super.init()
        let image = NSImage(systemSymbolName: "character.cursor.ibeam", accessibilityDescription: "Translate Under Cursor is on")
            ?? NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Translate Under Cursor is on")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "Translate Under Cursor is on"
        item.button?.setAccessibilityLabel("Translate Under Cursor is on")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    func remove() {
        NSStatusBar.system.removeStatusItem(item)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let title = NSMenuItem(title: "Translate Under Cursor Is On", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        let detail = NSMenuItem(title: summary(), action: nil, keyEquivalent: "")
        detail.isEnabled = false
        menu.addItem(detail)
        menu.addItem(.separator())
        let stopItem = NSMenuItem(title: "Stop Translating Under Cursor", action: #selector(stopChosen), keyEquivalent: "")
        stopItem.target = self
        stopItem.image = NSImage(systemSymbolName: "stop.circle", accessibilityDescription: nil)
        menu.addItem(stopItem)
    }

    @objc private func stopChosen() {
        stop()
    }
}
