import AppKit

/// Duplicates: files with the same content below the folder shown, found on request, in groups with what removing the
/// extra copies would free. Copies are marked with their checkbox or Select All but Newest (or Oldest), then go to the
/// Trash together, after the usual confirmation.
final class DuplicatesViewController: NSViewController, DiskContentController, NSOutlineViewDataSource, NSOutlineViewDelegate {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let outline = DiskOutlineView()
    private let header = NSStackView()
    private let icons = NodeIcons()
    private var items: [DuplicateGroupItem] = []
    private var shown: DuplicateSearch?
    private var tree: ScanTree?

    init(model: DiskAnalyzerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let mark = NodeColumns.Spec(id: "mark", title: "", width: 24, key: nil)
        let wasted = NodeColumns.Spec(id: "wasted", title: "Frees", width: 90, key: nil, alignment: .right)
        NodeColumns.add([mark, NodeColumns.name, NodeColumns.size, wasted, NodeColumns.modified, NodeColumns.folder], to: outline)
        for column in outline.tableColumns {
            column.sortDescriptorPrototype = nil
        }
        outline.outlineTableColumn = outline.tableColumn(withIdentifier: NSUserInterfaceItemIdentifier("name"))
        outline.dataSource = self
        outline.delegate = self
        outline.allowsMultipleSelection = true
        outline.usesAlternatingRowBackgroundColors = true
        outline.style = .fullWidth
        outline.onSpace = { [weak self] in self?.actions?.quickLook() }
        outline.menuProvider = { [weak self] in self.flatMap { $0.actions?.menu(for: $0.selectedNodes) } }
        outline.setAccessibilityLabel("Duplicates")
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 8
        header.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        let stack = NSStackView(views: [header, scroll])
        stack.orientation = .vertical
        stack.spacing = 6
        header.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        view = stack
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    func exportableNodes() -> [Int32] {
        items.flatMap(\.group.files)
    }

    private var selectedNodes: [Int32] {
        outline.selectedRowIndexes.compactMap { (outline.item(atRow: $0) as? NodeBox)?.node }
    }

    // MARK: Following the model

    private func render() {
        let search = model.duplicates
        _ = model.duplicateMarks
        _ = model.treeVersion
        tree = model.tree
        if search != shown {
            shown = search
            if case let .found(groups, _) = search {
                items = groups.map(DuplicateGroupItem.init)
            } else {
                items = []
            }
            outline.reloadData()
            outline.expandItem(nil, expandChildren: true)
        } else {
            outline.reloadData(forRowIndexes: IndexSet(0 ..< outline.numberOfRows), columnIndexes: [0])
        }
        showHeader(for: search)
    }

    private func showHeader(for search: DuplicateSearch) {
        for view in header.arrangedSubviews {
            header.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let folder = "“\(model.displayName(of: model.focus))”"
        switch search {
        case .idle:
            header.addArrangedSubview(PageParts.text("""
            Look for files with the same content in \(folder), among the files the scan kept one by one. Files are compared \
            by size, then by their first and last bytes, then by a checksum of all of it; nothing is changed.
            """))
            header.addArrangedSubview(ButtonRow([("Find Duplicates", { [weak self] in self?.model.findDuplicates() })]))
        case let .searching(progress):
            let bar = NSProgressIndicator()
            bar.style = .bar
            bar.isIndeterminate = progress == nil
            bar.minValue = 0
            bar.maxValue = Double(max(1, progress?.totalBytes ?? 1))
            bar.doubleValue = Double(progress?.doneBytes ?? 0)
            if progress == nil {
                bar.startAnimation(nil)
            }
            header.addArrangedSubview(PageParts.text(searchingText(progress)))
            header.addArrangedSubview(bar)
            bar.widthAnchor.constraint(equalTo: header.widthAnchor, constant: -24).isActive = true
            header.addArrangedSubview(ButtonRow([("Stop", { [weak self] in self?.model.cancelDuplicates() })], primaryFirst: false))
        case let .found(groups, folder):
            header.addArrangedSubview(PageParts.text(foundText(groups, folder: folder), secondary: false))
            header.addArrangedSubview(ButtonRow(foundButtons(groups), primaryFirst: false))
        }
    }

    private func searchingText(_ progress: DuplicateFinder.Progress?) -> String {
        guard let progress else { return "Looking for files of the same size…" }
        switch progress.stage {
        case .comparingEnds:
            return "Comparing the first and last bytes: \(progress.doneBytes.formatted()) of \(progress.totalBytes.formatted()) files…"
        case .comparingContents:
            return "Comparing contents: \(DiskFormat.bytes(progress.doneBytes)) of \(DiskFormat.bytes(progress.totalBytes))…"
        }
    }

    private func foundText(_ groups: [DuplicateGroup], folder: Int32) -> String {
        let place = "“\(model.displayName(of: folder))”"
        guard !groups.isEmpty else { return "No duplicates in \(place)." }
        let frees = groups.reduce(Int64(0)) { $0 + $1.reclaimable }
        let marked = model.duplicateMarks
        let markedBytes = tree.map { tree in marked.filter(tree.contains).reduce(Int64(0)) { $0 + tree[$1].size } } ?? 0
        var text = "\(DiskFormat.count(groups.count, "group")) of duplicates in \(place); keeping one copy of each frees "
            + "\(DiskFormat.bytes(frees))."
        if !marked.isEmpty {
            text += " Marked: \(DiskFormat.count(marked.count, "copy", plural: "copies")), \(DiskFormat.bytes(markedBytes))."
        }
        return text
    }

    private func foundButtons(_ groups: [DuplicateGroup]) -> [(title: String, action: () -> Void)] {
        guard !groups.isEmpty else { return [("Search Again", { [weak self] in self?.model.findDuplicates() })] }
        var buttons: [(title: String, action: () -> Void)] = [
            ("Mark All but Newest", { [weak self] in self?.model.markAllButOne(keeping: .newest) }),
            ("Mark All but Oldest", { [weak self] in self?.model.markAllButOne(keeping: .oldest) }),
        ]
        if !model.duplicateMarks.isEmpty {
            buttons.append(("Unmark All", { [weak self] in self?.model.duplicateMarks = [] }))
            buttons.append(("Move Marked to Trash…", { [weak self] in
                guard let self else { return }
                actions?.trash(Array(model.duplicateMarks))
            }))
        }
        buttons.append(("Search Again", { [weak self] in self?.model.findDuplicates() }))
        return buttons
    }

    // MARK: Data source

    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? DuplicateGroupItem)?.files.count ?? (item == nil ? items.count : 0)
    }

    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? DuplicateGroupItem)?.files[index] ?? items[index]
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        item is DuplicateGroupItem
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor column: NSTableColumn?, item: Any) -> NSView? {
        guard let column, let tree else { return nil }
        if let group = item as? DuplicateGroupItem {
            return groupCell(group, column: column.identifier.rawValue, in: outlineView)
        }
        guard let node = (item as? NodeBox)?.node, tree.contains(node) else { return nil }
        switch column.identifier.rawValue {
        case "mark":
            let box = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleMark))
            box.tag = Int(node)
            box.state = model.duplicateMarks.contains(node) ? .on : .off
            box.setAccessibilityLabel("Mark \(model.displayName(of: node))")
            return box
        case "name":
            let icon = icons.icon(for: node, in: tree) { model.displayPath(of: node) }
            return TableCells.name(
                in: outlineView,
                icon: icon,
                title: model.displayName(of: node),
                dimmed: false,
                badge: tree[node].flags.contains(.sharesBlocks) ? "· shares space with a clone" : nil
            )
        case "size": return TableCells.number(in: outlineView, DiskFormat.bytes(tree[node].size))
        case "modified": return TableCells.text(in: outlineView, DiskFormat.compact(tree[node].modifiedDate))
        case "folder": return TableCells.text(in: outlineView, model.displayPath(of: tree[node].parent))
        default: return nil
        }
    }

    private func groupCell(_ item: DuplicateGroupItem, column: String, in outlineView: NSOutlineView) -> NSView? {
        let group = item.group
        switch column {
        case "name":
            let name = tree.map { tree in group.files.first.map { tree.contains($0) ? tree.name(of: $0) : "" } ?? "" } ?? ""
            let cell = TableCells.text(in: outlineView, "\(group.files.count) copies of “\(name)”", secondary: false)
            cell.textField?.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
            return cell
        case "size": return TableCells.number(in: outlineView, DiskFormat.bytes(group.size))
        case "wasted": return TableCells.number(in: outlineView, DiskFormat.bytes(group.reclaimable))
        default: return nil
        }
    }

    @objc private func toggleMark(_ sender: NSButton) {
        let node = Int32(sender.tag)
        if sender.state == .on {
            model.duplicateMarks.insert(node)
        } else {
            model.duplicateMarks.remove(node)
        }
    }

    func outlineViewSelectionDidChange(_: Notification) {
        model.selection = selectedNodes
    }
}
