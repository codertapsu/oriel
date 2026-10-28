import AppKit
import OrielCore
import SharedUI

/// The status item and its menu (PLAN §10.1), rebuilt each time it opens so it always reflects state.
@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private unowned let controller: AppController

    init(controller: AppController) {
        self.controller = controller
        super.init()
        let image = NSImage(named: "StatusIcon") ?? NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "Oriel")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.setAccessibilityLabel("Oriel")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    /// A red record glyph while a recording runs, so it is never forgotten.
    func showRecording(_ isRecording: Bool) {
        guard let button = statusItem.button else { return }
        if isRecording {
            let image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Oriel is recording")
            button.image = image
            button.contentTintColor = .systemRed
        } else {
            let image = NSImage(named: "StatusIcon") ?? NSImage(
                systemSymbolName: "macwindow.on.rectangle",
                accessibilityDescription: "Oriel"
            )
            image?.isTemplate = true
            button.image = image
            button.contentTintColor = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !controller.permissions.allRequiredGranted {
            menu.addItem(item(.showOnboarding))
            menu.addItem(.separator())
        }
        let moduleItems = controller.registry.menuItems
        if !moduleItems.isEmpty {
            moduleItems.forEach(menu.addItem)
            menu.addItem(.separator())
        }
        for action in [AppAction.captureArea, .captureWindow, .captureScreen, .captureScrolling, .capturePreviousArea, .captureWithTimer] {
            menu.addItem(item(action))
        }
        menu.addItem(.separator())
        if controller.hub.isRecording {
            menu.addItem(item(.stopRecording))
        } else {
            menu.addItem(item(.recordArea))
            menu.addItem(item(.recordWindow))
            menu.addItem(item(.recordScreen))
        }
        menu.addItem(.separator())
        menu.addItem(item(.translateArea))
        menu.addItem(.separator())
        for action in [AppAction.showCaptureHistory, .showTranslationHistory, .openImage] where controller.hub.isAvailable(action) {
            menu.addItem(item(action))
        }
        menu.addItem(pinnedItem())
        menu.addItem(.separator())
        menu.addItem(item(.showSettings))
        menu.addItem(item(.quit))
    }

    /// Pinned captures, to bring one to the front or close them all; dimmed while nothing is pinned, because an item
    /// with neither an action nor a submenu is disabled.
    private func pinnedItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Pinned", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pinned")
        item.submenu = controller.hub.capture.makePinnedMenu()
        return item
    }

    private func item(_ action: AppAction) -> NSMenuItem {
        let shortcut = AppAction.shortcutActions.contains(action) ? controller.settings[action.shortcutKey] : nil
        let item = ActionMenuItemFactory.make(action, shortcut: shortcut) { [weak controller] in controller?.perform(action) }
        if action == .showSettings {
            item.keyEquivalent = ","
            item.keyEquivalentModifierMask = .command
        }
        item.isEnabled = controller.hub.isAvailable(action) || [.showSettings, .showOnboarding, .quit].contains(action)
        return item
    }
}
