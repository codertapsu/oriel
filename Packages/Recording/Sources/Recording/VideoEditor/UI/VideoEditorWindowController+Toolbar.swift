import AppKit

extension NSToolbarItem.Identifier {
    static let openMovie = NSToolbarItem.Identifier("openMovie")
    static let autoZoom = NSToolbarItem.Identifier("autoZoom")
    static let addZoom = NSToolbarItem.Identifier("addZoom")
    static let addChapter = NSToolbarItem.Identifier("addChapter")
    static let copyText = NSToolbarItem.Identifier("copyText")
    static let export = NSToolbarItem.Identifier("export")
}

/// The video editor's toolbar: Open, then Auto Zoom, Add Zoom, Add Chapter and Copy Text from Frame, then Export
/// and the inspector.
extension VideoEditorWindowController: NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [
            .openMovie,
            .flexibleSpace,
            .autoZoom,
            .addZoom,
            .addChapter,
            .copyText,
            .space,
            .export,
            .inspectorTrackingSeparator,
            .flexibleSpace,
            .toggleInspector,
        ]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _: NSToolbar,
        itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        let item: NSToolbarItem
        switch identifier {
        case .openMovie:
            item = makeItem(identifier, "Open", symbol: "folder", tip: "Open another movie (⌘O)", command: .open)
        case .autoZoom:
            item = makeItem(identifier, "Auto Zoom", symbol: "sparkles", tip: "Zoom in on the recording's clicks", command: .autoZoom)
        case .addZoom:
            item = makeItem(
                identifier,
                "Add Zoom",
                symbol: "plus.magnifyingglass",
                tip: "Add a zoom at the playhead (Z)",
                command: .addZoom
            )
        case .addChapter:
            item = makeItem(identifier, "Add Chapter", symbol: "bookmark", tip: "Add a chapter at the playhead (M)", command: .addChapter)
        case .copyText:
            item = makeItem(
                identifier,
                "Copy Text",
                symbol: "text.viewfinder",
                tip: "Copy the text in the frame at the playhead (⇧⌘C)",
                command: .copyFrameText
            )
        case .export:
            item = makeItem(identifier, "Export", symbol: "square.and.arrow.up", tip: "Export the movie or a GIF (⌘E)", command: .export)
        default:
            return nil
        }
        register(item)
        // Items are made when the toolbar first shows, after the window's state was first applied.
        updateToolbar()
        return item
    }

    private func makeItem(
        _ identifier: NSToolbarItem.Identifier,
        _ label: String,
        symbol: String,
        tip: String,
        command: VideoEditorCommand
    ) -> NSToolbarItem {
        let item = ToolbarCommandItem(itemIdentifier: identifier, command: command) { [weak self] command in
            _ = self?.perform(command)
        }
        item.label = label
        item.paletteLabel = label
        item.toolTip = tip
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.autovalidates = false
        return item
    }
}
