import AppKit

/// The List view: the folder shown as an outline, largest first, with a bar for each item's share of its folder.
/// Folders expand in place; Return or a double-click on a folder shows it on its own.
final class ListViewController: NSViewController, DiskContentController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let outline = DiskOutlineView()
    private let icons = NodeIcons()
    private var tree: ScanTree?
    private var root: Int32 = ScanTree.rootIndex
    private var shownVersion = -1
    private var generation = -1
    private var boxes: [Int32: NodeBox] = [:]
    private var childCache: [Int32: [Int32]] = [:]
    private var sort = FileSort()
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
        let columns = [
            NodeColumns.name, NodeColumns.size, NodeColumns.share, NodeColumns.files, NodeColumns.kind, NodeColumns.modified,
            NodeColumns.accessed,
        ]
        NodeColumns.add(columns, to: outline)
        outline.outlineTableColumn = outline.tableColumns.first
        // Access dates say little on APFS, which updates them lazily; the header's menu brings the column back.
        outline.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("accessed"))?.isHidden = true
        outline.dataSource = self
        outline.delegate = self
        outline.allowsMultipleSelection = true
        outline.usesAlternatingRowBackgroundColors = true
        outline.style = .fullWidth
        outline.autosaveName = "OrielDiskList"
        outline.autosaveTableColumns = true
        outline.sortDescriptors = [NSSortDescriptor(key: FileSort.Key.size.rawValue, ascending: false)]
        outline.target = self
        outline.doubleAction = #selector(openClicked)
        outline.onReturn = { [weak self] in self?.openSelection() }
        outline.onSpace = { [weak self] in self?.actions?.quickLook() }
        outline.menuProvider = { [weak self] in self.flatMap { $0.actions?.menu(for: $0.selectedNodes) } }
        outline.setAccessibilityLabel("Contents of the folder")
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        view = scroll
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(outline)
    }

    func exportableNodes() -> [Int32] {
        guard let tree else { return [] }
        return sort.sorted(tree.descendants(of: root) { _ in true }, in: tree)
    }

    private var selectedNodes: [Int32] {
        outline.selectedRowIndexes.compactMap { (outline.item(atRow: $0) as? NodeBox)?.node }
    }

    // MARK: Following the model

    private func render() {
        let version = model.treeVersion
        let focus = model.focus
        let selection = model.selection
        guard let tree = model.tree, tree.contains(focus) else { return }
        if version != shownVersion || focus != root {
            if tree.generation != generation || focus != root {
                boxes = [:]
            }
            self.tree = tree
            root = focus
            shownVersion = version
            generation = tree.generation
            childCache = [:]
            outline.reloadData()
        }
        applySelection(selection)
    }

    /// Selects `selection`, opening the folders above a selected item chosen in another view so it can be seen.
    private func applySelection(_ selection: [Int32]) {
        if let tree {
            for node in selection where tree.contains(node) && tree.isAncestor(root, of: node) && node != root {
                for ancestor in tree.lineage(of: node).drop(while: { $0 != root }).dropFirst().dropLast() {
                    outline.expandItem(box(ancestor))
                }
            }
        }
        let rows = IndexSet(selection.compactMap { node in boxes[node].map(outline.row(forItem:)) }.filter { $0 >= 0 })
        guard rows != outline.selectedRowIndexes else { return }
        isApplyingSelection = true
        outline.selectRowIndexes(rows, byExtendingSelection: false)
        if let first = rows.first {
            outline.scrollRowToVisible(first)
        }
        isApplyingSelection = false
    }

    private func box(_ node: Int32) -> NodeBox {
        if let known = boxes[node] {
            return known
        }
        let box = NodeBox(node)
        boxes[node] = box
        return box
    }

    private func sortedChildren(of node: Int32) -> [Int32] {
        if let known = childCache[node] {
            return known
        }
        guard let tree else { return [] }
        let sorted = sort.sorted(tree.children(of: node), in: tree)
        childCache[node] = sorted
        return sorted
    }

    // MARK: Data source

    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        sortedChildren(of: (item as? NodeBox)?.node ?? root).count
    }

    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        box(sortedChildren(of: (item as? NodeBox)?.node ?? root)[index])
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let tree, let node = (item as? NodeBox)?.node else { return false }
        return tree[node].kind.isContainer && tree[node].firstChild != ScanNode.none
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        guard let sort = NodeColumns.sort(from: outlineView.sortDescriptors) else { return }
        self.sort = sort
        childCache = [:]
        let selected = selectedNodes
        outlineView.reloadData()
        applySelection(selected)
    }

    // MARK: Cells

    func outlineView(_ outlineView: NSOutlineView, viewFor column: NSTableColumn?, item: Any) -> NSView? {
        guard let tree, let column, let node = (item as? NodeBox)?.node, tree.contains(node) else { return nil }
        let item = tree[node]
        switch column.identifier.rawValue {
        case "name":
            let icon = icons.icon(for: node, in: tree) { model.displayPath(of: node) }
            let dimmed = item.flags.contains(.excluded) || item.flags.contains(.unreadable) || item.kind == .smallFiles
            return TableCells.name(
                in: outlineView,
                icon: icon,
                title: model.displayName(of: node),
                dimmed: dimmed,
                badge: NodeColumns.badge(of: item)
            )
        case "size":
            return TableCells.number(in: outlineView, DiskFormat.bytes(item.size))
        case "share":
            let parent = item.parent == ScanNode.none ? item.size : tree[item.parent].size
            let fraction = parent > 0 ? Double(item.size) / Double(parent) : 0
            return TableCells.share(in: outlineView, fraction: fraction, text: DiskFormat.share(item.size, of: parent))
        case "files":
            let count = item.kind.isContainer || item.kind == .smallFiles ? item.fileCount.formatted() : ""
            return TableCells.number(in: outlineView, count)
        case "kind":
            return TableCells.text(in: outlineView, NodeColumns.kind(of: item))
        case "modified":
            return TableCells.text(in: outlineView, DiskFormat.compact(item.modifiedDate))
        case "accessed":
            return TableCells.text(in: outlineView, DiskFormat.compact(item.accessedDate))
        default:
            return nil
        }
    }

    func outlineViewSelectionDidChange(_: Notification) {
        guard !isApplyingSelection else { return }
        model.selection = selectedNodes
    }

    // MARK: Opening

    @objc private func openClicked() {
        guard let node = (outline.item(atRow: outline.clickedRow) as? NodeBox)?.node else { return }
        open(node)
    }

    private func openSelection() {
        guard selectedNodes.count == 1, let node = selectedNodes.first else { return }
        open(node)
    }

    private func open(_ node: Int32) {
        guard let tree else { return }
        if tree[node].kind.isContainer, tree[node].firstChild != ScanNode.none {
            model.open(node)
        } else {
            model.selection = [node]
            actions?.quickLook()
        }
    }
}
