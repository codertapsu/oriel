import AppKit

extension NSToolbarItem.Identifier {
    static let activityQuit = NSToolbarItem.Identifier("ActivityMonitor.quit")
    static let activityInfo = NSToolbarItem.Identifier("ActivityMonitor.info")
    static let activityActions = NSToolbarItem.Identifier("ActivityMonitor.actions")
    static let activityTabs = NSToolbarItem.Identifier("ActivityMonitor.tabs")
    static let activityFilter = NSToolbarItem.Identifier("ActivityMonitor.filter")
    static let activitySearch = NSToolbarItem.Identifier("ActivityMonitor.search")
}

/// The toolbar: Quit Process, Info and the actions menu on the left, the tabs in the middle, the view menu and search
/// on the right, as in macOS's Activity Monitor.
extension ActivityWindowController: NSToolbarDelegate, NSToolbarItemValidation {
    func makeToolbar() -> NSToolbar {
        let toolbar = NSToolbar(identifier: "ActivityMonitor.toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false
        toolbar.centeredItemIdentifiers = [.activityTabs]
        rebuildFilterMenu()
        return toolbar
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.activityQuit, .activityInfo, .activityActions, .flexibleSpace, .activityTabs, .flexibleSpace, .activityFilter, .activitySearch]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        switch identifier {
        case .activityQuit:
            return button(
                identifier,
                "Quit Process",
                symbol: "xmark.octagon",
                action: #selector(quitClicked),
                toolTip: "Quit the selected process (⌥⌘Q)"
            )
        case .activityInfo:
            return button(
                identifier,
                "Info",
                symbol: "info.circle",
                action: #selector(infoClicked),
                toolTip: "Show or hide the details (⌘I)"
            )
        case .activityActions:
            let item = NSMenuToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "ellipsis.circle", accessibilityDescription: "More")
            item.label = "More"
            item.toolTip = "Send a signal, sample, reveal or copy"
            item.menu = actionsMenu
            item.showsIndicator = false
            return item
        case .activityTabs:
            let item = NSToolbarItem(itemIdentifier: identifier)
            tabs.segmentStyle = .automatic
            tabs.setAccessibilityLabel("Measure")
            for (index, tab) in ActivityTab.allCases.enumerated() {
                tabs.setToolTip("\(tab.title) (⌘\(tab.keyEquivalent))", forSegment: index)
            }
            item.view = tabs
            item.label = "Measure"
            return item
        case .activityFilter:
            let item = NSMenuToolbarItem(itemIdentifier: identifier)
            item.image = NSImage(systemSymbolName: "line.3.horizontal.decrease.circle", accessibilityDescription: "View")
            item.label = "View"
            item.toolTip = "Which processes to show"
            item.menu = filterMenu
            return item
        case .activitySearch:
            searchItem.searchField.placeholderString = "Search processes"
            searchItem.searchField.setAccessibilityLabel("Search processes")
            searchItem.preferredWidthForSearchField = 200
            return searchItem
        default:
            return nil
        }
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        switch item.itemIdentifier {
        case .activityQuit: !list.selectedProcesses.isEmpty
        default: true
        }
    }

    /// The view menu, with a tick on the current view. Views about other users go while only the user's own processes
    /// are listed.
    func rebuildFilterMenu() {
        filterMenu.removeAllItems()
        let filters = ViewFilter.allCases.filter { !model.onlyMine || !$0.isAboutOtherUsers }
        for (index, filter) in filters.enumerated() {
            if filter == .hierarchy || filter == .apps {
                filterMenu.addItem(.separator())
            }
            let item = NSMenuItem(title: filter.title, action: #selector(filterChosen), keyEquivalent: "")
            item.target = self
            item.representedObject = filter.rawValue
            item.image = NSImage(systemSymbolName: filter.symbol, accessibilityDescription: nil)
            item.state = filter == model.effectiveFilter ? .on : .off
            item.tag = index
            filterMenu.addItem(item)
        }
    }

    private func button(
        _ identifier: NSToolbarItem.Identifier,
        _ label: String,
        symbol: String,
        action: Selector,
        toolTip: String
    ) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.label = label
        item.toolTip = toolTip
        item.target = self
        item.action = action
        item.isBordered = true
        return item
    }

    @objc private func quitClicked() {
        quitSelection(force: false)
    }

    @objc private func infoClicked() {
        toggleInspector()
    }

    @objc private func filterChosen(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let filter = ViewFilter(rawValue: raw) else { return }
        select(filter: filter)
        rebuildFilterMenu()
    }
}
