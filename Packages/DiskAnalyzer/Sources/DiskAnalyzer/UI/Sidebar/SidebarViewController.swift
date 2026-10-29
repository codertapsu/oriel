import AppKit
import SharedUI

/// The sidebar: the volumes with their capacity and purgeable space, the cloud storage folders, and the folders
/// scanned before. Selecting one shows it; double-clicking scans it.
final class SidebarViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let outline = NSOutlineView()
    private var sections: [SidebarItem] = []
    private var items: [String: SidebarItem] = [:]
    private var isApplyingSelection = false

    init(model: DiskAnalyzerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("source"))
        outline.addTableColumn(column)
        outline.outlineTableColumn = column
        outline.headerView = nil
        outline.style = .sourceList
        outline.rowSizeStyle = .custom
        outline.floatsGroupRows = false
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.doubleAction = #selector(doubleClicked)
        outline.setAccessibilityLabel("Volumes and folders")
        let menu = NSMenu()
        menu.delegate = self
        outline.menu = menu
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        view = scroll
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    // MARK: Following the model

    private func render() {
        let volumes = model.volumes
        let clouds = model.clouds
        let records = model.recentFolders
        let source = model.source
        _ = model.records
        sections = [
            section("Locations", volumes.map { item($0.path, .volume($0)) }),
            section("Cloud", clouds.map { item($0.path, .cloud($0)) }),
            section("Recent Scans", records.map { item("record:" + $0.rootPath, .record($0)) }),
        ].filter { !$0.children.isEmpty }
        outline.reloadData()
        for section in sections {
            outline.expandItem(section)
        }
        select(source)
    }

    private func section(_ title: String, _ children: [SidebarItem]) -> SidebarItem {
        let section = item("section:" + title, .section(title))
        section.children = children
        return section
    }

    private func item(_ id: String, _ kind: SidebarItem.Kind) -> SidebarItem {
        let item = items[id] ?? SidebarItem(id: id, kind: kind)
        item.kind = kind
        items[id] = item
        return item
    }

    private func select(_ source: DiskSource?) {
        isApplyingSelection = true
        defer { isApplyingSelection = false }
        let row = sections.flatMap(\.children).first { $0.source == source }.map(outline.row(forItem:)) ?? -1
        if row >= 0 {
            outline.selectRowIndexes([row], byExtendingSelection: false)
        } else {
            outline.deselectAll(nil)
        }
    }

    // MARK: Data source and delegate

    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? SidebarItem)?.children.count ?? sections.count
    }

    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? SidebarItem)?.children[index] ?? sections[index]
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? SidebarItem)?.isSection == true
    }

    func outlineView(_: NSOutlineView, isGroupItem item: Any) -> Bool {
        (item as? SidebarItem)?.isSection == true
    }

    func outlineView(_: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        (item as? SidebarItem)?.isSection == false
    }

    func outlineView(_: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        guard let item = item as? SidebarItem else { return 24 }
        switch item.kind {
        case .section: return 26
        case .volume: return 50
        case .cloud, .record: return 40
        }
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor _: NSTableColumn?, item: Any) -> NSView? {
        guard let item = item as? SidebarItem else { return nil }
        if case let .section(title) = item.kind {
            let header = NSTextField(labelWithString: title)
            header.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
            header.textColor = .secondaryLabelColor
            return header
        }
        let identifier = NSUserInterfaceItemIdentifier("SidebarCell")
        let cell = outlineView.makeView(withIdentifier: identifier, owner: nil) as? SidebarCellView ?? SidebarCellView()
        cell.identifier = identifier
        switch item.kind {
        case let .volume(volume):
            let free = DiskFormat.bytes(volume.usage.availableIncludingPurgeable)
            cell.show(
                symbol: volume.kind.symbol,
                title: volume.name,
                detail: "\(free) available of \(DiskFormat.bytes(volume.usage.total))",
                usage: volume.usage
            )
        case let .cloud(location):
            cell.show(symbol: location.provider.symbol, title: location.title, detail: location.account ?? "Downloaded files", usage: nil)
        case let .record(record):
            let detail = "\(DiskFormat.bytes(record.totalBytes)) · \(DiskFormat.day(record.date))"
            cell.show(symbol: "clock.arrow.circlepath", title: record.displayName, detail: detail, usage: nil)
        case .section:
            break
        }
        return cell
    }

    func outlineViewSelectionDidChange(_: Notification) {
        guard !isApplyingSelection else { return }
        let item = outline.item(atRow: outline.selectedRow) as? SidebarItem
        model.source = item?.source
    }

    @objc private func doubleClicked() {
        guard let item = outline.item(atRow: outline.clickedRow) as? SidebarItem, let source = item.source else { return }
        actions?.scan(source.path)
    }

    // MARK: Context menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let item = outline.item(atRow: outline.clickedRow) as? SidebarItem, let source = item.source else { return }
        let path = source.path
        menu.addItem(ActionMenuItem("Scan", symbol: "play") { [weak self] in self?.actions?.scan(path) })
        menu.addItem(ActionMenuItem("Reveal in Finder", symbol: "folder") { SystemLinks.reveal([URL(fileURLWithPath: path)]) })
        switch item.kind {
        case let .volume(volume):
            if volume.kind == .startup {
                menu.addItem(ActionMenuItem("Open Storage Settings", symbol: "gearshape") { SystemLinks.open(SystemLinks.storageSettings) })
            }
            if volume.canEject {
                menu.addItem(.separator())
                menu.addItem(ActionMenuItem("Eject “\(volume.name)”", symbol: "eject") { [weak self] in self?.actions?.eject(volume) })
            }
        case let .cloud(location):
            if let page = location.provider.storagePage {
                menu.addItem(ActionMenuItem("Open Storage Plan", symbol: "cloud") { SystemLinks.open(page) })
            }
        case .record:
            menu.addItem(.separator())
            menu.addItem(ActionMenuItem("Forget This Folder's Scans", symbol: "trash.slash") { [weak self] in
                self?.model.forgetScans(of: path)
            })
        case .section:
            break
        }
    }
}
