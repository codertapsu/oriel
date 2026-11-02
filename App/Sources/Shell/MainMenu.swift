import AppKit

/// Oriel's menu bar, shown while it is in the Dock (`DockPresence`). Its key equivalents work in Oriel's panels too,
/// where it is not shown: without it, ⌘C/⌘V/⌘Z/⌘W would do nothing in Settings, the editor or a text field. ⌘Q closes
/// Oriel's windows and leaves it running in the menu bar; only Quit in its menu-bar menu quits it (PLAN §10.1).
enum MainMenu {
    static func install(
        settings: @escaping @MainActor @Sendable () -> Void,
        tour: @escaping @MainActor @Sendable () -> Void,
        closeWindows: @escaping @MainActor @Sendable () -> Void
    ) {
        let main = NSMenu()
        let app = NSMenu(title: "Oriel")
        app.addItem(withTitle: "About Oriel", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(ActionMenuItemFactory.make("Settings…", key: ",", handler: settings))
        app.addItem(.separator())
        app.addItem(withTitle: "Hide Oriel", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(ActionMenuItemFactory.make("Close All Windows", key: "q", handler: closeWindows))
        main.addItem(submenu: app, title: "Oriel")

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu: edit, title: "Edit")

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        window.addItem(.separator())
        window.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        main.addItem(submenu: window, title: "Window")
        NSApp.windowsMenu = window

        let help = NSMenu(title: "Help")
        help.addItem(ActionMenuItemFactory.make("Oriel Feature Tour", handler: tour))
        help.addItem(ActionMenuItemFactory.make("Oriel Support") { NSWorkspace.shared.open(OrielLinks.support) })
        main.addItem(submenu: help, title: "Help")
        NSApp.helpMenu = help
        NSApp.mainMenu = main
    }
}

private extension NSMenu {
    func addItem(submenu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
