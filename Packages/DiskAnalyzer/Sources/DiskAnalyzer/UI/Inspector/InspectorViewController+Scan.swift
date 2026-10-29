import AppKit

/// The inspector for the scan as a whole, and for the blocks that stand for space rather than files.
extension InspectorViewController {
    func scanViews(_ tree: ScanTree) -> [NSView] {
        guard let summary = model.summary, let target = model.target else { return itemViews(ScanTree.rootIndex, in: tree) }
        var facts: [PageParts.Fact] = [
            .init("Size", DiskFormat.bytes(tree.root.size)),
            .init("Files", summary.files.formatted()),
            .init("Folders", summary.folders.formatted()),
            .init("Scanned", DiskFormat.date(summary.startedAt)),
            .init("Took", DiskFormat.duration(summary.duration)),
        ]
        if summary.cloudOnlyFiles > 0 {
            facts.append(.init("Only in the cloud", "\(summary.cloudOnlyFiles.formatted()) · \(DiskFormat.bytes(summary.cloudOnlyBytes))"))
        }
        var views: [NSView] = [
            PageParts.title(target.displayName, size: 15),
            PageParts.text(target.requestedPath, size: NSFont.smallSystemFontSize),
            PageParts.facts(facts),
        ]
        if summary.duplicateLinks > 0 {
            views.append(PageParts.text(
                "\(DiskFormat.count(summary.duplicateLinks, "further hard link")) to files counted once.",
                size: NSFont.smallSystemFontSize
            ))
        }
        if summary.unreadableFolders > 0 {
            views += unreadableViews(summary)
        }
        views.append(PageParts.separator())
        var buttons: [(title: String, action: () -> Void)] = [("Scan Again", { [weak self] in self?.model.rescan() })]
        if model.diff != nil {
            buttons.append(("Show Changes…", { [weak self] in self?.actions?.showChanges() }))
        }
        buttons.append(("Export as CSV…", { [weak self] in self?.actions?.exportCSV() }))
        views.append(ButtonRow(buttons, primaryFirst: false))
        views.append(PageParts.text("""
        Sizes are what files take on disk. APFS clones share their space, which no public interface can measure cheaply, \
        so a cloned file counts in full each time; selecting one shows what deleting it would free.
        """, size: NSFont.smallSystemFontSize))
        return views
    }

    private func unreadableViews(_ summary: ScanSummary) -> [NSView] {
        var views: [NSView] = [
            PageParts.separator(),
            PageParts.heading("\(DiskFormat.count(summary.unreadableFolders, "folder")) could not be read"),
            PageParts.text("""
            macOS keeps some folders from apps without Full Disk Access: Mail, Messages, Safari, other apps' containers and \
            other users' folders. Their space is not counted. After granting it, quit and reopen Oriel, then scan again.
            """, size: NSFont.smallSystemFontSize),
        ]
        for path in summary.unreadableSamples.prefix(5) {
            let field = PageParts.text(path, secondary: false, size: NSFont.smallSystemFontSize)
            field.lineBreakMode = .byTruncatingMiddle
            field.maximumNumberOfLines = 1
            views.append(field)
        }
        views.append(ButtonRow([("Grant Full Disk Access…", { SystemLinks.open(SystemLinks.fullDiskAccess) })], primaryFirst: false))
        return views
    }

    func syntheticViews(_ node: Int32, in tree: ScanTree) -> [NSView] {
        let item = tree[node]
        let title = model.displayName(of: node)
        var facts: [PageParts.Fact] = [.init("Size", DiskFormat.bytes(item.size))]
        if item.kind == .smallFiles {
            facts.append(.init("Files", Int(item.fileCount).formatted()))
        }
        var views: [NSView] = [PageParts.title(title, size: 15), PageParts.facts(facts)]
        switch item.kind {
        case .system:
            views.append(PageParts.text("""
            The sealed macOS system and the volumes macOS uses to start up, update and swap memory (Preboot, Update, VM). \
            It is read-only and is not scanned file by file. Nothing in it can or should be removed.
            """))
        case .unaccounted:
            views.append(PageParts.text("""
            Used space that no scanned file accounts for: local Time Machine snapshots, other volumes of the same APFS \
            container, folders Oriel could not read, and the file system's own records. The volume's overview shows the \
            snapshots.
            """))
            if (model.summary?.unreadableFolders ?? 0) > 0 {
                views.append(ButtonRow(
                    [("Grant Full Disk Access…", { SystemLinks.open(SystemLinks.fullDiskAccess) })],
                    primaryFirst: false
                ))
            }
        case .smallFiles:
            let threshold = DiskFormat.bytes(Int64(model.settings[DiskSettings.smallFileThreshold]))
            views.append(PageParts.text("""
            The files of “\(model.displayName(of: item.parent))” smaller than \(threshold), counted together: listing \
            millions of small files one by one would take a lot of memory and tell little. Their total is exact. Settings \
            → Disk Space Analyzer sets the size.
            """))
            views.append(ButtonRow(
                [("Reveal Folder in Finder", { [weak self] in self?.model.revealInFinder([item.parent]) })],
                primaryFirst: false
            ))
        default:
            break
        }
        return views
    }
}
