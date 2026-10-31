import AppKit

/// Space Hogs: the usual suspects — caches, Xcode's build data, simulators, device backups, installers, `node_modules`
/// — with what each is, whether it comes back by itself, how much it takes here, one safe action, and Clean Up, which
/// checks the folder first (PLAN §7.10 item 19). Measured only when asked, since reading some of these folders makes
/// macOS ask for access.
final class SpaceHogsViewController: NSViewController, DiskContentController, NSTableViewDataSource, NSTableViewDelegate {
    weak var actions: DiskActions?
    private let model: DiskAnalyzerModel
    private let table = DiskTableView()
    private let header = NSStackView()
    private let hogs = SpaceHogCatalog.all
    private var measured = false

    init(model: DiskAnalyzerModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        NodeColumns.add([
            NodeColumns.Spec(id: "hog", title: "What", width: 340, key: nil),
            NodeColumns.Spec(id: "size", title: "Size here", width: 150, key: nil, alignment: .right),
            NodeColumns.Spec(id: "action", title: "", width: 290, key: nil),
        ], to: table)
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 52
        table.style = .fullWidth
        table.usesAlternatingRowBackgroundColors = true
        table.selectionHighlightStyle = .none
        table.target = self
        table.doubleAction = #selector(reveal)
        table.setAccessibilityLabel("Space hogs")
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        header.orientation = .horizontal
        header.spacing = 10
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

    private func render() {
        _ = model.hogs
        _ = model.treeVersion
        measured = model.hasMeasuredHogs
        table.reloadData()
        for view in header.arrangedSubviews {
            header.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let note = PageParts.text(measured
            ? "Sizes on this Mac now. Folders found by name come from the open scan."
            : "Oriel measures these folders when you ask. Reading some of them makes macOS ask for access the first time.")
        note.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(note)
        let measure: () -> Void = { [weak self] in self?.model.measureHogs() }
        header.addArrangedSubview(ButtonRow([(measured ? "Measure Again" : "Measure Space Hogs", measure)], primaryFirst: !measured))
    }

    func numberOfRows(in _: NSTableView) -> Int {
        hogs.count
    }

    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        guard let column, hogs.indices.contains(row) else { return nil }
        let hog = hogs[row]
        let measurement = model.hogs[hog.id]
        switch column.identifier.rawValue {
        case "hog": return HogCellView(hog: hog)
        case "size": return TableCells.number(in: tableView, sizeText(hog, measurement))
        case "action": return actions(for: hog, measurement: measurement, row: row)
        default: return nil
        }
    }

    private func sizeText(_ hog: SpaceHog, _ measurement: HogMeasurement?) -> String {
        switch measurement {
        case nil: return "—"
        case .measuring?: return "Measuring…"
        case .none?: return "None"
        case .unreadable?: return hog.needsFullDiskAccess ? "Full Disk Access" : "Can't be read"
        case let .measured(bytes, items)?:
            if case .foldersNamed = hog.location {
                return "\(DiskFormat.bytes(bytes)) in \(DiskFormat.count(items.count, "folder"))"
            }
            return DiskFormat.bytes(bytes)
        }
    }

    /// The hog's own action, then Clean Up.
    private func actions(for hog: SpaceHog, measurement: HogMeasurement?, row: Int) -> NSView {
        let stack = NSStackView(views: [
            actionButton(for: hog, measurement: measurement, row: row), cleanUpControl(for: hog, measurement: measurement, row: row),
        ])
        stack.spacing = 6
        let container = NSView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    /// Clean Up of the hog's folder (for installers, of Downloads, where they are); for folders found by name, a menu of
    /// them. Available once the hog was measured and found.
    private func cleanUpControl(for hog: SpaceHog, measurement: HogMeasurement?, row: Int) -> NSControl {
        let found = if case let .measured(_, items)? = measurement {
            items
        } else {
            [String]()
        }
        guard case .foldersNamed = hog.location else {
            let button = NSButton(title: "Clean Up…", target: self, action: #selector(cleanUp(_:)))
            button.tag = row
            button.controlSize = .small
            button.bezelStyle = .push
            button.isEnabled = !found.isEmpty
            return button
        }
        let menu = NSPopUpButton(frame: .zero, pullsDown: true)
        menu.controlSize = .small
        menu.addItem(withTitle: "Clean Up")
        for path in found.prefix(20) {
            let item = NSMenuItem(
                title: (path as NSString).abbreviatingWithTildeInPath,
                action: #selector(cleanUpFolder(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = path
            menu.menu?.addItem(item)
        }
        menu.isEnabled = !found.isEmpty
        menu.setAccessibilityLabel("Clean Up a \(hog.title) folder")
        return menu
    }

    private func actionButton(for hog: SpaceHog, measurement: HogMeasurement?, row: Int) -> NSButton {
        let title = switch hog.action {
        case .trashContents, .trashItems: "Move to Trash…"
        case .reveal: "Show in Finder"
        case .deleteUnavailableSimulators: "Delete Unavailable…"
        case .openTrash: "Open Trash"
        }
        let button = NSButton(title: title, target: self, action: #selector(act))
        button.tag = row
        button.controlSize = .small
        button.bezelStyle = .push
        let hasItems = !(measurement?.items.isEmpty ?? true) && (measurement?.bytes ?? 0) > 0
        switch hog.action {
        case .trashContents, .trashItems: button.isEnabled = hasItems
        case .reveal: button.isEnabled = hasItems
        case .deleteUnavailableSimulators: button.isEnabled = Simulators.exist()
        case .openTrash: button.isEnabled = true
        }
        return button
    }

    @objc private func act(_ sender: NSButton) {
        guard hogs.indices.contains(sender.tag) else { return }
        let hog = hogs[sender.tag]
        let measurement = model.hogs[hog.id]
        switch hog.action {
        case .trashContents, .trashItems:
            guard let measurement else { return }
            actions?.trash(paths: measurement.items, bytes: measurement.bytes, title: hog.title.lowercased())
        case .reveal:
            SystemLinks.reveal((measurement?.items ?? []).prefix(50).map { URL(fileURLWithPath: $0) })
        case .deleteUnavailableSimulators:
            actions?.deleteUnavailableSimulators()
        case .openTrash:
            SystemLinks.openTrash()
        }
    }

    @objc private func cleanUp(_ sender: NSButton) {
        guard hogs.indices.contains(sender.tag), let folder = hogs[sender.tag].folder(home: NSHomeDirectory()) else { return }
        actions?.cleanUp(path: folder)
    }

    @objc private func cleanUpFolder(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        actions?.cleanUp(path: path)
    }

    @objc private func reveal() {
        guard hogs.indices.contains(table.clickedRow) else { return }
        let hog = hogs[table.clickedRow]
        let items = model.hogs[hog.id]?.items ?? []
        let paths = items.isEmpty ? hog.folder(home: NSHomeDirectory()).map { [$0] } ?? [] : Array(items.prefix(50))
        SystemLinks.reveal(paths.filter { FileManager.default.fileExists(atPath: $0) }.map { URL(fileURLWithPath: $0) })
    }
}
