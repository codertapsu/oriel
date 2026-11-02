import AppKit
import OrielCore
import SharedUI

/// Context menus, the window's shortcuts, and ⌘C.
extension DiskWindowController {
    func menu(for nodes: [Int32]) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        guard let tree = model.tree else { return menu }
        let nodes = nodes.filter { tree.contains($0) && !tree[$0].kind.isSynthetic && $0 != ScanTree.rootIndex }
        guard !nodes.isEmpty else {
            addFolderItems(to: menu)
            return menu
        }
        if nodes.count == 1, tree[nodes[0]].kind.isContainer, tree[nodes[0]].firstChild != ScanNode.none {
            menu.addItem(item("Show Contents", symbol: "arrow.down.right.circle") { [weak self] in self?.model.open(nodes[0]) })
        }
        menu.addItem(item("Open", symbol: "arrow.up.forward.app") { [weak self] in self?.model.openItems(nodes) })
        menu.addItem(item("Reveal in Finder", symbol: "folder") { [weak self] in self?.model.revealInFinder(nodes) })
        menu.addItem(item("Quick Look", symbol: "eye") { [weak self] in
            self?.model.selection = nodes
            self?.quickLook()
        })
        if nodes.count == 1, tree[nodes[0]].kind.isContainer {
            menu.addItem(item("Clean Up…", symbol: "sparkles") { [weak self] in self?.cleanUp(nodes[0]) })
            menu.items.last.map { ProMenuBadge.apply(.cleanUp, to: $0) }
        }
        menu.addItem(.separator())
        menu.addItem(item("Copy", symbol: "doc.on.clipboard") { [weak self] in
            guard let self else { return }
            Pasteboard.copy(fileURLs: nodes.map(model.url(of:)))
        })
        menu.addItem(item("Copy Path", symbol: "link") { [weak self] in self?.model.copyPaths(nodes) })
        menu.addItem(.separator())
        menu.addItem(item("Copy to…", symbol: "doc.on.doc") { [weak self] in self?.copyTo(nodes) })
        let refused = nodes.allSatisfy { model.refusal(for: $0) != nil }
        let move = item("Move to…", symbol: "arrow.forward.folder") { [weak self] in self?.moveTo(nodes) }
        menu.addItem(move)
        if nodes.contains(where: model.canRemoveDownload) {
            menu.addItem(item("Remove Download", symbol: "icloud.and.arrow.up") { [weak self] in self?.model.removeDownloads(nodes) })
        }
        menu.addItem(.separator())
        let trash = item("Move to Trash", symbol: "trash", key: "\u{8}") { [weak self] in self?.trash(nodes) }
        let delete = item("Delete Immediately…", symbol: "xmark.circle", key: "\u{8}", modifiers: [.command, .option]) { [weak self] in
            self?.deleteImmediately(nodes)
        }
        menu.addItem(trash)
        menu.addItem(delete)
        for entry in [move, trash, delete] {
            entry.isEnabled = !refused
            entry.toolTip = refused ? nodes.first.flatMap(model.refusal(for:)) : nil
        }
        if nodes.count == 1, tree[nodes[0]].kind.isContainer {
            addFolderTools(for: nodes[0], to: menu)
        }
        return menu
    }

    /// For the folder shown, when nothing is selected.
    private func addFolderItems(to menu: NSMenu) {
        let focus = model.focus
        menu.addItem(item("Reveal in Finder", symbol: "folder") { [weak self] in self?.model.revealInFinder([focus]) })
        menu.addItem(item("Copy Path", symbol: "link") { [weak self] in self?.model.copyPaths([focus]) })
        if model.tree?[focus].kind.isContainer == true {
            menu.addItem(item("Clean Up…", symbol: "sparkles") { [weak self] in self?.cleanUp(focus) })
            menu.items.last.map { ProMenuBadge.apply(.cleanUp, to: $0) }
        }
        menu.addItem(.separator())
        menu.addItem(item("Scan Again", symbol: "arrow.clockwise") { [weak self] in self?.model.rescan() })
        menu.addItem(item("Export as CSV…", symbol: "square.and.arrow.up") { [weak self] in self?.exportCSV() })
        menu.items.last.map { ProMenuBadge.apply(.csvExport, to: $0) }
    }

    private func addFolderTools(for node: Int32, to menu: NSMenu) {
        let path = model.displayPath(of: node)
        menu.addItem(.separator())
        menu.addItem(item("Scan This Folder", symbol: "scope") { [weak self] in self?.scan(path) })
        menu.addItem(item("Exclude from Scans", symbol: "eye.slash") { [weak self] in
            guard let self else { return }
            var exclusions = model.settings[DiskSettings.exclusions]
            if !exclusions.contains(path) {
                exclusions.append(path)
                model.settings[DiskSettings.exclusions] = exclusions
            }
            present(.init(title: "“\((path as NSString).lastPathComponent)” is excluded", text: """
            The next scan skips it. Settings → Disk Space Analyzer → Exclusions lists what is excluded.
            """))
        })
    }

    private func item(
        _ title: String,
        symbol: String,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        handler: @escaping @MainActor @Sendable () -> Void
    ) -> NSMenuItem {
        ActionMenuItem(title, symbol: symbol, key: key, modifiers: modifiers, handler: handler)
    }

    // MARK: Keys

    /// The window's shortcuts. Typing in the search field keeps ⌘⌫ and the arrows for the text.
    func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        let editing = window?.firstResponder is NSText
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        switch (flags, event.specialKey) {
        case ([.command], .upArrow?) where !editing:
            model.goUp()
        case ([.command], .delete?) where !editing:
            trash(model.actionableSelection)
        case ([.command, .option], .delete?) where !editing:
            deleteImmediately(model.actionableSelection)
        default:
            return handleCommandKey(key, flags: flags)
        }
        return true
    }

    private func handleCommandKey(_ key: String, flags: NSEvent.ModifierFlags) -> Bool {
        if flags == [.command], let number = Int(key), (1 ... DiskView.allCases.count).contains(number) {
            model.view = DiskView.allCases[number - 1]
            model.search = ""
            return true
        }
        switch (flags, key) {
        case ([.command], "r"): scanAction(nil)
        case ([.command], "."): model.stopScan()
        case ([.command], "o"): chooseFolder()
        case ([.command], "y"): quickLook()
        case ([.command], "f"): window?.makeFirstResponder(searchItem.searchField)
        case ([.command, .option], "i"): split.splitViewItems.last?.animator().isCollapsed.toggle()
        default: return false
        }
        return true
    }

    /// Edit → Copy: the selected items, as Finder copies them, so they paste as files or as paths.
    @objc func copy(_: Any?) {
        let nodes = model.actionableSelection
        guard !nodes.isEmpty else {
            NSSound.beep()
            return
        }
        Pasteboard.copy(fileURLs: nodes.map(model.url(of:)))
    }
}
