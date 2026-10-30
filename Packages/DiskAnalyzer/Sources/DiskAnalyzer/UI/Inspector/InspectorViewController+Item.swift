import AppKit

/// The inspector for one item, and for the scan itself.
extension InspectorViewController {
    func itemViews(_ node: Int32, in tree: ScanTree) -> [NSView] {
        let item = tree[node]
        if item.kind.isSynthetic {
            return syntheticViews(node, in: tree)
        }
        var views: [NSView] = [header(node, in: tree)]
        views += sizeRows(node, in: tree)
        views.append(PageParts.separator())
        views += placeRows(node)
        views += dateRows(item, node: node)
        let notes = notes(for: item)
        if !notes.isEmpty {
            views.append(PageParts.separator())
            views += notes.map { PageParts.text($0, size: NSFont.smallSystemFontSize) }
        }
        if let refusal = model.refusal(for: node) {
            views.append(refusalNote("Oriel won't remove or move it. \(refusal)"))
        }
        views.append(PageParts.separator())
        views.append(ButtonRow(buttons(for: node, item: item), primaryFirst: false))
        return views
    }

    private func header(_ node: Int32, in tree: ScanTree) -> NSView {
        let icon = NSImageView(image: NodeIcons().icon(for: node, in: tree) { model.displayPath(of: node) })
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let name = PageParts.title(model.displayName(of: node), size: 15)
        name.isSelectable = true
        let kind = PageParts.text(NodeColumns.kind(of: tree[node]), size: NSFont.smallSystemFontSize)
        let texts = NSStackView(views: [name, kind])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 2
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [icon, texts])
        row.spacing = 10
        row.alignment = .centerY
        return row
    }

    private func sizeRows(_ node: Int32, in tree: ScanTree) -> [NSView] {
        let item = tree[node]
        var facts: [PageParts.Fact] = [.init("On disk", DiskFormat.bytes(item.size))]
        if item.logicalSize > 0, abs(item.logicalSize - item.size) > max(item.size / 50, 4096) {
            facts.append(.init(item.flags.contains(.cloudOnly) ? "In the cloud" : "Content", DiskFormat.bytes(item.logicalSize)))
        }
        if let looked = self.facts, looked.node == node, let privateSize = looked.clone?.privateSize, abs(privateSize - item.size) > 4096 {
            facts.append(.init("Freed if deleted", DiskFormat.bytes(privateSize)))
        }
        if item.kind.isContainer {
            facts.append(.init("Files", Int(item.fileCount).formatted()))
            facts.append(.init("Folders", Int(item.folderCount).formatted()))
        }
        if node != ScanTree.rootIndex {
            facts.append(.init("Share of scan", DiskFormat.share(item.size, of: tree.root.size)))
        }
        return [PageParts.facts(facts)]
    }

    private func placeRows(_ node: Int32) -> [NSView] {
        let path = PageParts.text(model.displayPath(of: node), secondary: false, size: NSFont.smallSystemFontSize)
        path.isSelectable = true
        path.lineBreakMode = .byCharWrapping
        return [PageParts.heading("Where"), path]
    }

    private func dateRows(_ item: ScanNode, node: Int32) -> [NSView] {
        var facts: [PageParts.Fact] = []
        if let created = item.createdDate {
            facts.append(.init("Created", DiskFormat.date(created)))
        }
        if let modified = item.modifiedDate {
            facts.append(.init("Modified", DiskFormat.date(modified)))
        }
        if let looked = self.facts, looked.node == node, let opened = looked.lastOpened {
            facts.append(.init("Last opened", DiskFormat.date(opened)))
        }
        if let accessed = item.accessedDate {
            facts.append(.init("Last accessed", DiskFormat.date(accessed)))
        }
        return facts.isEmpty ? [] : [PageParts.separator(), PageParts.facts(facts)]
    }

    private func notes(for item: ScanNode) -> [String] {
        let flags = item.flags
        var notes: [String] = []
        if flags.contains(.unreadable) {
            let why = switch UnreadableReason(flags: flags) {
            case .needsAdministrator:
                "Only its owner, macOS or another user, can open this folder, so what it holds is not counted. Full Disk Access "
                    + "does not change that; Read as Administrator, in the note above the views, does."
            case .protectedByMacOS:
                "macOS protects this folder, so what it holds is not counted. Full Disk Access opens it if it holds personal "
                    + "data; System Integrity Protection keeps it from every app."
            case .other:
                "Oriel could not read this folder, so what it holds is not counted."
            }
            notes.append(why)
        }
        if flags.contains(.readAsAdministrator) {
            notes.append(
                "Read with an administrator's rights. It stays as it was read until the next scan, and Oriel changes nothing in it."
            )
        }
        if flags.contains(.macOSVolume) {
            notes.append("Part of macOS's own volumes (the sealed system, Preboot, VM, Update): counted, never removed or moved.")
        }
        if flags.contains(.partial) {
            notes.append("Reading this folder stopped part way, so some of it is not counted.")
        }
        if flags.contains(.cloudOnly) {
            notes.append("Only in the cloud: it takes no space here and downloads when opened.")
        }
        if flags.contains(.sharesBlocks) {
            notes.append("APFS shares some of its space with a copy (a clone), so deleting it can free less than its size.")
        }
        if flags.contains(.duplicateLink) {
            notes.append("Another hard link to this file is counted elsewhere, so it adds no size here.")
        } else if flags.contains(.hardLink) {
            notes.append("This file has more than one hard link; its size is counted once.")
        }
        if flags.contains(.purgeable) {
            notes.append("macOS may delete it by itself when space runs low.")
        }
        if flags.contains(.excluded) {
            notes.append("Excluded from scans in Settings, so its size is not counted.")
        }
        if flags.contains(.mountPoint) {
            notes.append(item.firstChild == ScanNode.none
                ? "Another volume is mounted here; scan that volume to see it."
                : "Another volume is mounted here; its files are counted too.")
        }
        if flags.contains(.firmlink) {
            notes.append("A firmlink of macOS: its contents are counted where it points, on the data volume.")
        }
        if item.kind == .package {
            notes.append("macOS shows this as a single item; it is counted with everything inside it.")
        }
        return notes
    }

    private func buttons(for node: Int32, item: ScanNode) -> [(title: String, action: () -> Void)] {
        var buttons: [(title: String, action: () -> Void)] = [
            ("Reveal in Finder", { [weak self] in self?.model.revealInFinder([node]) }),
        ]
        if item.kind == .file, !item.flags.contains(.cloudOnly) {
            buttons.append(("Quick Look", { [weak self] in
                self?.model.selection = [node]
                self?.actions?.quickLook()
            }))
        }
        if model.canRemoveDownload(node) {
            buttons.append(("Remove Download", { [weak self] in self?.model.removeDownloads([node]) }))
        }
        if item.kind.isContainer {
            buttons.append(("Clean Up…", { [weak self] in self?.actions?.cleanUp(node) }))
        }
        if node != ScanTree.rootIndex, model.refusal(for: node) == nil {
            buttons.append(("Move to Trash…", { [weak self] in self?.actions?.trash([node]) }))
        }
        return buttons
    }
}
