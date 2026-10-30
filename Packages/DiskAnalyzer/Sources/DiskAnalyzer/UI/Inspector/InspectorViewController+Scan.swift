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

    /// What could not be read, grouped by why, with what helps each: Full Disk Access lifts macOS's privacy protection,
    /// not a folder's permissions (docs/os-quirks.md).
    private func unreadableViews(_ summary: ScanSummary) -> [NSView] {
        var views: [NSView] = [
            PageParts.separator(),
            PageParts.heading("\(DiskFormat.count(summary.unreadableFolders, "folder")) could not be read"),
        ]
        if summary.administratorFolders > 0 {
            views.append(PageParts.text("""
            \(DiskFormat.count(summary.administratorFolders, "folder")) can be opened only by their owner, macOS or another \
            user; Full Disk Access does not change that. Read as Administrator reads them with an administrator's rights and \
            changes nothing: through Oriel's helper, without asking, once you have allowed it in System Settings, or after \
            macOS asks for the password.
            """, size: NSFont.smallSystemFontSize))
            views += samples(summary.samples(.needsAdministrator))
            if !model.isReadingAsAdministrator {
                views.append(ButtonRow(
                    [("Read as Administrator…", { [weak self] in self?.actions?.readAsAdministrator() })],
                    primaryFirst: false
                ))
            }
        }
        if summary.protectedFolders > 0 {
            views.append(PageParts.text("""
            macOS protects \(DiskFormat.count(summary.protectedFolders, "folder")). Full Disk Access opens those holding \
            personal data (Mail, Messages, Safari, other apps' data); System Integrity Protection keeps the rest from every \
            app, even with an administrator's password. After granting Full Disk Access, quit and reopen Oriel, then scan again.
            """, size: NSFont.smallSystemFontSize))
            views += samples(summary.samples(.protectedByMacOS))
            views.append(ButtonRow([("Full Disk Access…", { SystemLinks.open(SystemLinks.fullDiskAccess) })], primaryFirst: false))
        }
        let others = summary.samples(.other)
        if !others.isEmpty {
            views.append(PageParts.text("The disk reported an error reading these:", size: NSFont.smallSystemFontSize))
            views += samples(others)
        }
        return views
    }

    private func samples(_ paths: [String]) -> [NSView] {
        paths.prefix(5).map { path in
            let field = PageParts.text(path, secondary: false, size: NSFont.smallSystemFontSize)
            field.lineBreakMode = .byTruncatingMiddle
            field.maximumNumberOfLines = 1
            return field
        }
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
        case .system where tree.anchors[item.parent] != nil:
            views.append(PageParts.text("""
            The volume macOS starts up from, with its cryptexes: Safari, the shared caches and Rosetta, which macOS grafts in \
            from disk images. Counted as the space the volume uses: those images are APFS clones of each other, so their \
            files would count the same space more than once. Nothing in it can or should be removed.
            """))
        case .system:
            views.append(PageParts.text("""
            The sealed macOS system and the volumes macOS uses to start up, update and swap memory (Preboot, Update, VM). \
            Nothing in it can or should be removed. To see what is inside, turn on Settings → Disk Space Analyzer → Count \
            macOS's own files one by one, and scan again.
            """))
        case .unaccounted:
            views.append(PageParts.text("""
            Used space that no scanned file accounts for: local Time Machine snapshots, other volumes of the same APFS \
            container, folders Oriel could not read, and the file system's own records. The volume's overview shows the \
            snapshots.
            """))
            if (model.summary?.administratorFolders ?? 0) > 0, !model.isReadingAsAdministrator {
                views.append(ButtonRow(
                    [("Read as Administrator…", { [weak self] in self?.actions?.readAsAdministrator() })],
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
