import AppKit

/// The filter bar and the query: rows are worked out again when the tree, the folder, the filter, the sort, the
/// search or Spotlight's dates change.
extension FileTableViewController {
    func makeFilterBar() -> NSView {
        caption.lineBreakMode = .byTruncatingTail
        caption.textColor = .secondaryLabelColor
        let threshold = DiskFormat.bytes(Int64(model.settings[DiskSettings.smallFileThreshold]))
        caption.toolTip = "Files smaller than \(threshold) are counted per folder and not listed one by one."
        caption.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        kindPopup.addItem(withTitle: "All Kinds")
        for category in FileCategory.allCases {
            kindPopup.addItem(withTitle: category.title)
        }
        sizePopup.addItems(withTitles: Self.sizeChoices.map(\.title))
        for (index, days) in DiskSettings.oldFileChoices.enumerated() {
            agePopup.addItem(withTitle: "Unused for \(DiskFormat.days(days))")
            agePopup.item(at: index)?.tag = days
        }
        agePopup.selectItem(withTag: model.settings[DiskSettings.oldFileDays])
        for popup in [kindPopup, sizePopup, agePopup] {
            popup.controlSize = .small
            popup.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            popup.target = self
            popup.action = #selector(filterChanged)
        }
        kindPopup.setAccessibilityLabel("Kind")
        sizePopup.setAccessibilityLabel("Size")
        agePopup.setAccessibilityLabel("Not used for")
        var views: [NSView] = [caption]
        if mode != .search {
            views += [kindPopup, sizePopup]
        }
        if mode == .old {
            views.append(agePopup)
        }
        let bar = NSStackView(views: views)
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        return bar
    }

    var filter: FileFilter {
        var filter = FileFilter()
        let kind = kindPopup.indexOfSelectedItem
        if kind > 0, FileCategory.allCases.indices.contains(kind - 1) {
            filter.categories = [FileCategory.allCases[kind - 1]]
        }
        filter.minimumSize = Self.sizeChoices[max(0, sizePopup.indexOfSelectedItem)].bytes
        if mode == .old {
            // From the start of today, so the filter stays the same, and the list too, until tomorrow.
            let days = model.settings[DiskSettings.oldFileDays]
            filter.lastUsedBefore = Calendar.current.startOfDay(for: Date()).addingTimeInterval(-Double(days) * 86400)
            filter.includesCloudOnly = false
        }
        return filter
    }

    @objc func filterChanged(_ sender: NSPopUpButton) {
        if sender === agePopup, let days = agePopup.selectedItem?.tag, days > 0 {
            model.settings[DiskSettings.oldFileDays] = days
        }
        render()
    }

    func render() {
        if mode == .biggest, let category = model.categoryRequest {
            model.categoryRequest = nil
            if let index = FileCategory.allCases.firstIndex(of: category) {
                kindPopup.selectItem(at: index + 1)
            }
        }
        let version = model.treeVersion
        let selection = model.selection
        let search = model.search
        let lastOpened = model.lastOpened
        let focus = model.focus
        _ = model.settings[DiskSettings.oldFileDays]
        guard let tree = model.tree, tree.contains(focus) else { return }
        let query = FileQuery(
            mode: mode,
            version: version,
            folder: focus,
            filter: filter,
            sort: sort,
            search: search,
            lastOpenedCount: lastOpened.count
        )
        if query != shownQuery {
            run(query, in: tree, lastOpened: lastOpened)
        } else {
            applySelection(selection)
        }
    }

    private func run(_ query: FileQuery, in tree: ScanTree, lastOpened: [Int32: Date]) {
        queryTask?.cancel()
        let debounce = mode == .search && shownQuery?.search != query.search
        queryTask = Task { [weak self] in
            if debounce {
                try? await Task.sleep(for: .milliseconds(160))
            }
            guard !Task.isCancelled else { return }
            let result = await Task.detached(priority: .userInitiated) { query.run(in: tree, lastOpened: lastOpened) }.value
            guard let self, !Task.isCancelled else { return }
            show(result, for: query, in: tree)
        }
    }

    private func show(_ result: FileQuery.Result, for query: FileQuery, in tree: ScanTree) {
        self.tree = tree
        rows = result.rows
        shownQuery = query
        table.reloadData()
        caption.stringValue = captionText(result, query: query)
        applySelection(model.selection)
        if mode == .old {
            // Spotlight knows better than the file system when a file was last opened: ask about the candidates.
            model.loadLastOpened(for: Array(result.rows.prefix(600)))
        }
    }

    private func captionText(_ result: FileQuery.Result, query: FileQuery) -> String {
        let folder = "“\(model.displayName(of: query.folder))”"
        let total = "\(DiskFormat.count(result.matches, mode == .search ? "item" : "file")), \(DiskFormat.bytes(result.bytes))"
        let cut = result.matches > result.rows.count ? ", the \(result.rows.count.formatted()) largest shown" : ""
        switch mode {
        case .biggest:
            return "\(total) in \(folder)\(cut)"
        case .old:
            let days = model.settings[DiskSettings.oldFileDays]
            return "Not used for \(DiskFormat.days(days)): \(total)\(cut)"
        case .search:
            return query.search.isEmpty ? "" : "“\(query.search)” in \(folder): \(total)\(cut)"
        }
    }

    func applySelection(_ selection: [Int32]) {
        let positions = Dictionary(rows.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let indexes = IndexSet(selection.compactMap { positions[$0] })
        guard indexes != table.selectedRowIndexes else { return }
        isApplyingSelection = true
        table.selectRowIndexes(indexes, byExtendingSelection: false)
        isApplyingSelection = false
    }
}
