import AppKit
import SharedUI

/// The process list: one outline view per tab, so each keeps its own columns, widths (AppKit saves them), order and
/// scroll position, while the selection follows the user from tab to tab.
///
/// Rows are `ProcessNode`s kept by key and updated in place. An update that leaves the order alone only redraws the
/// visible rows; one that changes it reloads, then puts back the selection, the expanded rows and the scroll position.
final class ProcessListController: NSObject {
    let model: ActivityListModel
    let icons = ProcessIconCache()
    /// Holds the current tab's list.
    let container = NSView()
    /// Shared by every tab's list; its delegate builds it when it opens.
    let contextMenu = NSMenu()

    var onSelectionChange: (() -> Void)?
    var onOpen: (() -> Void)?
    var onSortChange: ((ProcessSort) -> Void)?
    var onCopy: (() -> Void)?
    var onKeyDown: ((NSEvent) -> Bool)?
    /// What the flame in a row says, from the thresholds.
    var heavyNote: ((ProcessMetrics) -> String?)?

    private var outlines: [ActivityTab: ProcessOutlineView] = [:]
    private var nodes: [ListNode.Key: ProcessNode] = [:]
    private(set) var roots: [ProcessNode] = []
    /// The rows' keys in order, to tell an update that moves rows from one that only changes numbers.
    private var order: [ListNode.Key] = []
    private var shownTab: ActivityTab?
    private var selectedKeys: [ListNode.Key] = []
    /// Rows the user collapsed in the hierarchy, which is otherwise fully expanded.
    private var collapsed: Set<ListNode.Key> = []
    /// Apps the user expanded in Apps with Their Helpers, which otherwise shows them closed.
    private var expanded: Set<ListNode.Key> = []
    private var isUpdating = false
    private let emptyLabel = NSTextField(labelWithString: "")

    private let autosaves: Bool

    init(model: ActivityListModel, autosaves: Bool = true) {
        self.model = model
        self.autosaves = autosaves
        super.init()
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    var outline: ProcessOutlineView {
        outline(for: model.tab)
    }

    /// The selected rows' processes; a group row stands for its app's own process.
    var selectedProcesses: [ProcessMetrics] {
        outline.selectedRowIndexes.compactMap { (outline.item(atRow: $0) as? ProcessNode).map(process) }
    }

    /// Every process the selection covers: a group row brings all its members.
    var selectedMembers: [ProcessMetrics] {
        outline.selectedRowIndexes.flatMap { row -> [ProcessMetrics] in
            guard let node = outline.item(atRow: row) as? ProcessNode else { return [] }
            return node.isGroup ? node.children.map(\.metrics) : [node.metrics]
        }
    }

    /// The process of the row a context menu was opened on, else the selection.
    var clickedOrSelected: [ProcessMetrics] {
        let row = outline.clickedRow
        if row >= 0, !outline.selectedRowIndexes.contains(row), let node = outline.item(atRow: row) as? ProcessNode {
            return [process(node)]
        }
        return selectedProcesses
    }

    /// Shows `tab`'s list in the container.
    func show(_ tab: ActivityTab) {
        guard shownTab != tab else { return }
        shownTab = tab
        let outline = outline(for: tab)
        container.subviews.forEach { $0.removeFromSuperview() }
        if let scroll = outline.enclosingScrollView {
            scroll.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(scroll)
            container.addSubview(emptyLabel)
            NSLayoutConstraint.activate([
                scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                scroll.topAnchor.constraint(equalTo: container.topAnchor),
                scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -20),
                emptyLabel.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -40),
            ])
        }
        order = []
        reload()
    }

    /// Brings the list up to date with the model.
    func reload() {
        var used: Set<ListNode.Key> = []
        var newOrder: [ListNode.Key] = []
        roots = model.roots.map { node(for: $0, used: &used, order: &newOrder) }
        nodes = nodes.filter { used.contains($0.key) }
        let outline = outline
        isUpdating = true
        defer { isUpdating = false }
        if newOrder == order, outline.numberOfRows > 0 {
            let visible = outline.rows(in: outline.visibleRect)
            outline.reloadData(
                forRowIndexes: IndexSet(integersIn: visible.location ..< visible.location + visible.length),
                columnIndexes: IndexSet(integersIn: 0 ..< outline.numberOfColumns)
            )
        } else {
            order = newOrder
            let clip = outline.enclosingScrollView?.contentView
            let origin = clip?.bounds.origin
            outline.reloadData()
            restoreExpansion(outline)
            if let clip, let origin {
                clip.scroll(to: origin)
                outline.enclosingScrollView?.reflectScrolledClipView(clip)
            }
        }
        restoreSelection(outline)
        updateEmptyText()
    }

    /// Selects the row of `identity`, opening the rows above it, and scrolls to it.
    func select(_ identity: ProcessIdentity) {
        let outline = outline
        guard let node = nodes[.process(identity)] ?? nodes[.group(identity)] else { return }
        var ancestors: [ProcessNode] = []
        var current = parent(of: node)
        while let ancestor = current {
            ancestors.insert(ancestor, at: 0)
            current = parent(of: ancestor)
        }
        ancestors.forEach { outline.expandItem($0) }
        let row = outline.row(forItem: node)
        guard row >= 0 else { return }
        outline.selectRowIndexes([row], byExtendingSelection: false)
        outline.scrollRowToVisible(row)
    }

    // MARK: Rows

    private func node(for list: ListNode, used: inout Set<ListNode.Key>, order: inout [ListNode.Key]) -> ProcessNode {
        let node = nodes[list.key] ?? ProcessNode(key: list.key, metrics: list.metrics)
        node.metrics = list.metrics
        nodes[list.key] = node
        used.insert(list.key)
        order.append(list.key)
        node.children = list.children.map { self.node(for: $0, used: &used, order: &order) }
        return node
    }

    private func process(_ node: ProcessNode) -> ProcessMetrics {
        guard node.isGroup else { return node.metrics }
        return node.children.first { $0.metrics.id == node.key.identity }?.metrics ?? node.metrics
    }

    private func parent(of node: ProcessNode) -> ProcessNode? {
        outline.parent(forItem: node) as? ProcessNode
    }

    private func restoreExpansion(_ outline: NSOutlineView) {
        switch model.effectiveFilter {
        case .hierarchy:
            // AppKit keeps the expanded rows across a reload, so only rows that are new get opened.
            func open(_ nodes: [ProcessNode]) {
                for node in nodes where !node.children.isEmpty && !collapsed.contains(node.key) {
                    if !outline.isItemExpanded(node) {
                        outline.expandItem(node)
                    }
                    open(node.children)
                }
            }
            open(roots)
        case .appsWithHelpers:
            for key in expanded {
                if let node = nodes[key] {
                    outline.expandItem(node)
                }
            }
        default:
            break
        }
    }

    private func restoreSelection(_ outline: NSOutlineView) {
        let rows = IndexSet(selectedKeys.compactMap { nodes[$0] }.map { outline.row(forItem: $0) }.filter { $0 >= 0 })
        if rows != outline.selectedRowIndexes {
            outline.selectRowIndexes(rows, byExtendingSelection: false)
        }
        let keys = rows.compactMap { (outline.item(atRow: $0) as? ProcessNode)?.key }
        if keys != selectedKeys {
            // A selected process ended.
            selectedKeys = keys
            onSelectionChange?()
        }
    }

    private func updateEmptyText() {
        let empty = roots.isEmpty
        emptyLabel.isHidden = !empty
        guard empty else { return }
        if model.snapshot == nil {
            emptyLabel.stringValue = "Measuring…"
        } else if model.isSearching {
            emptyLabel.stringValue = "No processes match “\(model.query.trimmingCharacters(in: .whitespaces))”."
        } else {
            emptyLabel.stringValue = "No processes in \(model.effectiveFilter.title)."
        }
    }

    // MARK: Lists

    private func outline(for tab: ActivityTab) -> ProcessOutlineView {
        if let outline = outlines[tab] {
            return outline
        }
        let outline = ProcessOutlineView()
        for column in tab.columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.rawValue))
            tableColumn.title = column.title
            tableColumn.width = column.width
            tableColumn.minWidth = column == .name ? 140 : 44
            tableColumn.headerToolTip = column.headerToolTip
            tableColumn.headerCell.alignment = column.isNumeric ? .right : .left
            tableColumn.sortDescriptorPrototype = NSSortDescriptor(key: column.rawValue, ascending: column.sortsAscendingFirst)
            tableColumn.resizingMask = column == .name ? [.autoresizingMask, .userResizingMask] : .userResizingMask
            outline.addTableColumn(tableColumn)
        }
        outline.outlineTableColumn = outline.tableColumns.first
        outline.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outline.style = .fullWidth
        outline.usesAlternatingRowBackgroundColors = true
        outline.rowSizeStyle = .custom
        outline.rowHeight = 20
        outline.intercellSpacing = NSSize(width: 6, height: 0)
        outline.allowsMultipleSelection = true
        outline.allowsColumnReordering = true
        outline.indentationPerLevel = 14
        outline.autoresizesOutlineColumn = false
        if autosaves {
            outline.autosaveName = "ActivityMonitor.\(tab.rawValue)"
            outline.autosaveTableColumns = true
        }
        outline.headerView?.menu = columnMenu(for: outline)
        outline.setAccessibilityLabel("Processes")
        let sort = model.sorts[tab] ?? tab.defaultSort
        outline.sortDescriptors = [NSSortDescriptor(key: sort.column.rawValue, ascending: sort.ascending)]
        outline.dataSource = self
        outline.delegate = self
        outline.target = self
        outline.doubleAction = #selector(doubleClicked)
        outline.menu = contextMenu
        outline.onKeyDown = { [weak self] event in self?.keyDown(event) ?? false }
        outline.onCopy = { [weak self] in self?.onCopy?() }
        let scroll = NSScrollView()
        scroll.documentView = outline
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        outlines[tab] = outline
        return outline
    }

    /// A right-click on the header shows or hides columns; AppKit remembers the choice with the widths.
    private func columnMenu(for outline: NSOutlineView) -> NSMenu {
        let menu = NSMenu(title: "Columns")
        for tableColumn in outline.tableColumns.dropFirst() {
            let identifier = tableColumn.identifier
            let item = ActionMenuItem(tableColumn.title) { [weak outline, weak menu] in
                guard let outline, let column = outline.tableColumns.first(where: { $0.identifier == identifier }) else { return }
                let visible = outline.tableColumns.dropFirst().filter { !$0.isHidden }.count
                // The last numbers column stays, or the list would show names only.
                guard column.isHidden || visible > 1 else { return }
                column.isHidden.toggle()
                menu?.items.first { $0.title == column.title }?.state = column.isHidden ? .off : .on
            }
            item.state = tableColumn.isHidden ? .off : .on
            menu.addItem(item)
        }
        return menu
    }

    private func keyDown(_ event: NSEvent) -> Bool {
        if event.keyCode == 36 || event.keyCode == 76, event.modifierFlags.isDisjoint(with: .deviceIndependentFlagsMask) {
            onOpen?()
            return true
        }
        return onKeyDown?(event) ?? false
    }

    @objc private func doubleClicked() {
        guard outline.clickedRow >= 0 else { return }
        onOpen?()
    }
}

extension ProcessListController: NSOutlineViewDataSource, NSOutlineViewDelegate {
    func outlineView(_: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        (item as? ProcessNode)?.children.count ?? roots.count
    }

    func outlineView(_: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        (item as? ProcessNode)?.children[index] ?? roots[index]
    }

    func outlineView(_: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? ProcessNode)?.children.isEmpty == false
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? ProcessNode, let identifier = tableColumn?.identifier.rawValue,
              let column = ActivityColumn(rawValue: identifier)
        else { return nil }
        let process = node.metrics
        if column == .name {
            let cell = outlineView.makeView(withIdentifier: ProcessNameCell.identifier, owner: nil) as? ProcessNameCell ?? ProcessNameCell()
            cell.configure(process, icon: icons.icon(for: process), isGroup: node.isGroup, heavyNote: heavyNote?(process))
            return cell
        }
        let cell = outlineView.makeView(withIdentifier: MetricCell.identifier, owner: nil) as? MetricCell ?? MetricCell()
        let heavy = column.heavyFlag.map { process.heavy.contains($0) } ?? false
        let standIn = column.isStandIn(for: process)
        cell.configure(
            column.text(for: process),
            numeric: column.isNumeric,
            heavy: heavy,
            quiet: column.isQuiet(for: process),
            standIn: standIn,
            toolTip: standIn ? "Real memory: macOS shares the footprint only for your own processes." : nil
        )
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange _: [NSSortDescriptor]) {
        guard !isUpdating, let descriptor = outlineView.sortDescriptors.first, let key = descriptor.key,
              let column = ActivityColumn(rawValue: key)
        else { return }
        onSortChange?(ProcessSort(column: column, ascending: descriptor.ascending))
    }

    func outlineViewSelectionDidChange(_: Notification) {
        guard !isUpdating else { return }
        selectedKeys = outline.selectedRowIndexes.compactMap { (outline.item(atRow: $0) as? ProcessNode)?.key }
        onSelectionChange?()
    }

    func outlineViewItemDidExpand(_ notification: Notification) {
        guard !isUpdating, let node = notification.userInfo?["NSObject"] as? ProcessNode else { return }
        collapsed.remove(node.key)
        expanded.insert(node.key)
    }

    func outlineViewItemDidCollapse(_ notification: Notification) {
        guard !isUpdating, let node = notification.userInfo?["NSObject"] as? ProcessNode else { return }
        collapsed.insert(node.key)
        expanded.remove(node.key)
    }
}
