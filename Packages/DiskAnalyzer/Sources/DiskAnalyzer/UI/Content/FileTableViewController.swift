import AppKit

/// Biggest Files, Old Files and the search's results: a sortable list of files below the folder shown, with filters
/// for kind and size, and for Old Files how long they have not been used. The query runs off the main thread.
final class FileTableViewController: NSViewController, DiskContentController, NSTableViewDataSource, NSTableViewDelegate {
    weak var actions: DiskActions?
    let model: DiskAnalyzerModel
    let mode: FileQuery.Mode
    let table = DiskTableView()
    let caption = NSTextField(labelWithString: "")
    let kindPopup = NSPopUpButton()
    let sizePopup = NSPopUpButton()
    let agePopup = NSPopUpButton()
    private let icons = NodeIcons()
    var rows: [Int32] = []
    var tree: ScanTree?
    var sort = FileSort()
    var shownQuery: FileQuery?
    var queryTask: Task<Void, Never>?
    var isApplyingSelection = false

    static let sizeChoices: [(title: String, bytes: Int64)] = [
        ("Any Size", 0), ("10 MB or More", 10_000_000), ("100 MB or More", 100_000_000), ("1 GB or More", 1_000_000_000),
    ]

    init(model: DiskAnalyzerModel, mode: FileQuery.Mode) {
        self.model = model
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let columns: [NodeColumns.Spec] = switch mode {
        case .biggest: [NodeColumns.name, NodeColumns.size, NodeColumns.kind, NodeColumns.modified, NodeColumns.folder]
        case .old: [NodeColumns.name, NodeColumns.size, NodeColumns.opened, NodeColumns.modified, NodeColumns.folder]
        case .search: [NodeColumns.name, NodeColumns.size, NodeColumns.kind, NodeColumns.modified, NodeColumns.folder]
        }
        NodeColumns.add(columns, to: table)
        table.dataSource = self
        table.delegate = self
        table.allowsMultipleSelection = true
        table.usesAlternatingRowBackgroundColors = true
        table.style = .fullWidth
        table.autosaveName = "OrielDiskFiles-\(mode)"
        table.autosaveTableColumns = true
        table.sortDescriptors = [NSSortDescriptor(key: FileSort.Key.size.rawValue, ascending: false)]
        table.target = self
        table.doubleAction = #selector(openClicked)
        table.onReturn = { [weak self] in self?.openSelection() }
        table.onSpace = { [weak self] in self?.actions?.quickLook() }
        table.menuProvider = { [weak self] in self.flatMap { $0.actions?.menu(for: $0.selectedNodes) } }
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let bar = makeFilterBar()
        let stack = NSStackView(views: [bar, scroll])
        stack.orientation = .vertical
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        bar.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        view = stack
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if mode != .search {
            view.window?.makeFirstResponder(table)
        }
    }

    func exportableNodes() -> [Int32] {
        rows
    }

    var selectedNodes: [Int32] {
        table.selectedRowIndexes.compactMap { rows.indices.contains($0) ? rows[$0] : nil }
    }

    // MARK: Data source

    func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard let tree, let column, rows.indices.contains(row), tree.contains(rows[row]) else { return nil }
        let node = rows[row]
        let item = tree[node]
        switch column.identifier.rawValue {
        case "name":
            let icon = icons.icon(for: node, in: tree) { model.displayPath(of: node) }
            return TableCells.name(
                in: tableView,
                icon: icon,
                title: model.displayName(of: node),
                dimmed: false,
                badge: NodeColumns.badge(of: item)
            )
        case "size":
            let size = item.flags.contains(.cloudOnly) ? item.logicalSize : item.size
            return TableCells.number(in: tableView, DiskFormat.bytes(size))
        case "kind":
            return TableCells.text(in: tableView, NodeColumns.kind(of: item))
        case "modified":
            return TableCells.text(in: tableView, DiskFormat.compact(item.modifiedDate))
        case "opened":
            let lastUsed = FileFilter.lastUsed(item, lastOpened: model.lastOpened[node])
            return TableCells.text(in: tableView, lastUsed == .distantFuture ? "—" : DiskFormat.relative(lastUsed))
        case "folder":
            return TableCells.text(in: tableView, model.displayPath(of: item.parent))
        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        guard let sort = NodeColumns.sort(from: tableView.sortDescriptors) else { return }
        self.sort = sort
        render()
    }

    func tableViewSelectionDidChange(_: Notification) {
        guard !isApplyingSelection else { return }
        model.selection = selectedNodes
    }

    // MARK: Opening

    @objc private func openClicked() {
        guard rows.indices.contains(table.clickedRow) else { return }
        open(rows[table.clickedRow])
    }

    private func openSelection() {
        guard selectedNodes.count == 1, let node = selectedNodes.first else { return }
        open(node)
    }

    /// A folder is shown; a file is shown selected in its folder, the search cleared.
    private func open(_ node: Int32) {
        guard let tree else { return }
        if mode == .search {
            model.search = ""
            model.open(node)
            return
        }
        if tree[node].kind.isContainer {
            model.open(node)
        } else {
            model.selection = [node]
            actions?.quickLook()
        }
    }
}
