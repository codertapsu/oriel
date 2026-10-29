import AppKit

extension NSToolbarItem.Identifier {
    static let diskScan = NSToolbarItem.Identifier("disk.scan")
    static let diskStop = NSToolbarItem.Identifier("disk.stop")
    static let diskChoose = NSToolbarItem.Identifier("disk.choose")
    static let diskReveal = NSToolbarItem.Identifier("disk.reveal")
    static let diskQuickLook = NSToolbarItem.Identifier("disk.quickLook")
    static let diskCopy = NSToolbarItem.Identifier("disk.copy")
    static let diskMove = NSToolbarItem.Identifier("disk.move")
    static let diskTrash = NSToolbarItem.Identifier("disk.trash")
    static let diskSearch = NSToolbarItem.Identifier("disk.search")
}

/// The toolbar: Scan, Stop, Choose Folder…, Reveal in Finder, Quick Look, Copy to…, Move to…, Move to Trash, and the
/// search field, which filters the current folder's contents by name.
extension DiskWindowController: NSToolbarDelegate, NSSearchFieldDelegate {
    private struct ItemSpec {
        var label: String
        var symbol: String
        var tip: String
        var action: Selector
    }

    private static let specs: [NSToolbarItem.Identifier: ItemSpec] = [
        .diskScan: ItemSpec(
            label: "Scan",
            symbol: "play.fill",
            tip: "Scan the selected volume or folder (⌘R)",
            action: #selector(scanAction)
        ),
        .diskStop: ItemSpec(label: "Stop", symbol: "stop.fill", tip: "Stop the scan (⌘.)", action: #selector(stopAction)),
        .diskChoose: ItemSpec(
            label: "Choose Folder",
            symbol: "folder.badge.plus",
            tip: "Choose a folder to scan (⌘O)",
            action: #selector(chooseFolderAction)
        ),
        .diskReveal: ItemSpec(label: "Reveal in Finder", symbol: "folder", tip: "Reveal in Finder", action: #selector(revealAction)),
        .diskQuickLook: ItemSpec(label: "Quick Look", symbol: "eye", tip: "Quick Look (Space)", action: #selector(quickLookAction)),
        .diskCopy: ItemSpec(
            label: "Copy to",
            symbol: "doc.on.doc",
            tip: "Copy to another folder or volume…",
            action: #selector(copyToAction)
        ),
        .diskMove: ItemSpec(
            label: "Move to",
            symbol: "arrow.forward.folder",
            tip: "Move to another folder or volume…",
            action: #selector(moveToAction)
        ),
        .diskTrash: ItemSpec(label: "Move to Trash", symbol: "trash", tip: "Move to Trash (⌘⌫)", action: #selector(trashAction)),
    ]

    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "OrielDiskAnalyzer")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        return toolbar
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .toggleSidebar, .sidebarTrackingSeparator, .diskScan, .diskStop, .diskChoose, .flexibleSpace, .diskReveal, .diskQuickLook,
            .diskCopy, .diskMove, .diskTrash, .inspectorTrackingSeparator, .diskSearch, .toggleInspector,
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar) + [.space]
    }

    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        if identifier == .diskSearch {
            searchItem.searchField.delegate = self
            searchItem.searchField.placeholderString = "Search this folder"
            searchItem.searchField.sendsSearchStringImmediately = false
            searchItem.preferredWidthForSearchField = 200
            searchItem.label = "Search"
            return searchItem
        }
        guard let spec = Self.specs[identifier] else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = spec.label
        item.paletteLabel = spec.label
        item.toolTip = spec.tip
        item.image = NSImage(systemSymbolName: spec.symbol, accessibilityDescription: spec.label)
        item.target = self
        item.action = spec.action
        item.isBordered = true
        item.autovalidates = false
        toolbarItems[identifier] = item
        return item
    }

    /// Enables what applies to the current state.
    func updateToolbar() {
        let hasSelection = !model.actionableSelection.isEmpty
        let content = model.content
        let canScan = switch content {
        case .volume, .cloud, .record, .scan: true
        case .welcome, .scanning: false
        }
        toolbarItems[.diskScan]?.isEnabled = canScan && model.operation == nil
        toolbarItems[.diskStop]?.isEnabled = model.phase.isScanning
        toolbarItems[.diskReveal]?.isEnabled = content == .scan
        toolbarItems[.diskQuickLook]?.isEnabled = hasSelection
        for identifier in [NSToolbarItem.Identifier.diskCopy, .diskMove, .diskTrash] {
            toolbarItems[identifier]?.isEnabled = hasSelection && model.operation == nil && content == .scan
        }
        searchItem.searchField.isEnabled = content == .scan
        let isTyping = window?.firstResponder === searchItem.searchField.currentEditor()
        if model.search.isEmpty, !searchItem.searchField.stringValue.isEmpty, !isTyping {
            searchItem.searchField.stringValue = ""
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSSearchField, field === searchItem.searchField else { return }
        model.search = field.stringValue
    }

    func searchFieldDidEndSearching(_: NSSearchField) {
        model.search = ""
    }

    // MARK: Actions

    @objc func scanAction(_: Any?) {
        switch model.content {
        case let .volume(volume): scan(volume.path)
        case let .cloud(location): scan(location.path)
        case let .record(record): scan(record.rootPath)
        case .scan: model.rescan()
        case .welcome, .scanning: break
        }
    }

    @objc func stopAction(_: Any?) {
        model.stopScan()
    }

    @objc func chooseFolderAction(_: Any?) {
        chooseFolder()
    }

    @objc func revealAction(_: Any?) {
        let nodes = model.actionableSelection
        model.revealInFinder(nodes.isEmpty ? [model.focus] : nodes)
    }

    @objc func quickLookAction(_: Any?) {
        quickLook()
    }

    @objc func copyToAction(_: Any?) {
        copyTo(model.actionableSelection)
    }

    @objc func moveToAction(_: Any?) {
        moveTo(model.actionableSelection)
    }

    @objc func trashAction(_: Any?) {
        trash(model.actionableSelection)
    }
}
