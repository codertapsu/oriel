import AppKit

/// File Types: how the scanned space divides between videos, pictures, apps, archives… counted exactly over every
/// file the scan read, the small ones too. Double-clicking a kind lists its biggest files.
final class FileTypesViewController: NSViewController, DiskContentController, NSTableViewDataSource, NSTableViewDelegate {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let table = DiskTableView()
    private let caption = NSTextField(wrappingLabelWithString: "")
    private var totals = CategoryTotals()
    private var rows: [FileCategory] = []

    init(model: DiskAnalyzerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let specs = [
            NodeColumns.Spec(id: "kind", title: "Kind", width: 230, key: nil),
            NodeColumns.Spec(id: "share", title: "Share", width: 200, key: nil),
            NodeColumns.Spec(id: "size", title: "Size", width: 90, key: nil, alignment: .right),
            NodeColumns.Spec(id: "files", title: "Files", width: 90, key: nil, alignment: .right),
        ]
        NodeColumns.add(specs, to: table)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 26
        table.style = .fullWidth
        table.usesAlternatingRowBackgroundColors = true
        table.target = self
        table.doubleAction = #selector(showFiles)
        table.onReturn = { [weak self] in self?.showFiles() }
        table.setAccessibilityLabel("File types")
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        caption.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [caption, scroll])
        stack.orientation = .vertical
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 0, right: 0)
        caption.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24).isActive = true
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        view = stack
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        ObservationLoop.run(while: { [weak self] in self != nil }, render: { [weak self] in self?.render() })
    }

    private func render() {
        guard let summary = model.summary else { return }
        totals = summary.categories
        rows = totals.ranked
        table.reloadData()
        caption.stringValue = """
        Every file of “\(model.target?.displayName ?? "")”, \(DiskFormat.count(totals.totalCount, "file")) taking \
        \(DiskFormat.bytes(totals.totalBytes)), by kind; the files of an app or a library count with it. Double-click a kind \
        to list its biggest files.
        """
    }

    func numberOfRows(in _: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard let column, rows.indices.contains(row) else { return nil }
        let category = rows[row]
        let bytes = totals.bytes(of: category)
        switch column.identifier.rawValue {
        case "kind":
            let icon = NSImage(systemSymbolName: category.symbol, accessibilityDescription: nil) ?? NSImage()
            return TableCells.name(in: tableView, icon: icon, title: category.title, dimmed: false)
        case "share":
            let whole = max(1, totals.totalBytes)
            return TableCells.share(
                in: tableView,
                fraction: Double(bytes) / Double(whole),
                text: DiskFormat.share(bytes, of: whole),
                tint: ChartPalette.fill(branch: row, depth: 1, kind: .file)
            )
        case "size":
            return TableCells.number(in: tableView, DiskFormat.bytes(bytes))
        case "files":
            return TableCells.number(in: tableView, totals.count(of: category).formatted())
        default:
            return nil
        }
    }

    @objc private func showFiles() {
        let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        guard rows.indices.contains(row) else { return }
        model.categoryRequest = rows[row]
        model.focus = ScanTree.rootIndex
        model.view = .biggest
    }
}
