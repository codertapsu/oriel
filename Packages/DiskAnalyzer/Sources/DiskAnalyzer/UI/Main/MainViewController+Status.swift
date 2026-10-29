import AppKit

/// The notes above the views and the status line below them.
extension MainViewController {
    struct Note {
        var id: String
        var symbol: String
        var tint: NSColor
        var text: String
        var button: String?
        var action: (() -> Void)?
    }

    func notes() -> [Note] {
        guard let summary = model.summary else { return [] }
        var notes: [Note] = []
        if case .ready(stopped: true) = model.phase {
            notes.append(Note(
                id: "stopped",
                symbol: "pause.circle",
                tint: .systemOrange,
                text: "The scan was stopped, so these totals cover only what it had read.",
                button: "Scan Again"
            ) { [weak self] in
                self?.model.rescan()
            })
        }
        if summary.unreadableFolders > 0 {
            let count = DiskFormat.count(summary.unreadableFolders, "folder")
            notes.append(Note(
                id: "unreadable",
                symbol: "lock",
                tint: .systemOrange,
                text: "\(count) could not be read, so their space is not counted. macOS shows them to apps with Full Disk Access.",
                button: "Grant Full Disk Access…"
            ) { SystemLinks.open(SystemLinks.fullDiskAccess) })
        }
        if let diff = model.diff, abs(diff.totalDelta) >= 50_000_000 {
            notes.append(Note(
                id: "diff",
                symbol: "chart.line.uptrend.xyaxis",
                tint: .controlAccentColor,
                text: "Since the scan of \(DiskFormat.day(diff.since)): \(DiskFormat.change(diff.totalDelta)).",
                button: "Show Changes"
            ) { [weak self] in self?.actions?.showChanges() })
        }
        return notes.filter { !model.hiddenNotes.contains($0.id) }
    }

    func updateBanners(isScan: Bool) {
        let notes = isScan ? notes() : []
        let ids = notes.map { "\($0.id):\($0.text)" }
        guard ids != shownBannerIDs else { return }
        shownBannerIDs = ids
        for view in bannerStack.arrangedSubviews {
            bannerStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for note in notes {
            let id = note.id
            let banner = BannerView(
                symbol: note.symbol, tint: note.tint, text: note.text, button: note.button, action: note.action,
                onClose: { [weak self] in self?.model.hiddenNotes.insert(id) }
            )
            bannerStack.addArrangedSubview(banner)
            banner.widthAnchor.constraint(equalTo: bannerStack.widthAnchor, constant: -24).isActive = true
        }
    }

    func updateStatus() {
        switch model.phase {
        case .idle:
            statusLine.stringValue = ""
        case let .scanning(progress):
            statusLine.stringValue = "Scanning… \(DiskFormat.count(progress.files, "file")), \(DiskFormat.bytes(progress.bytes))"
        case .ready:
            guard let summary = model.summary, let tree = model.tree else { return }
            var parts = [
                "\(DiskFormat.count(summary.files, "file")) and \(DiskFormat.count(summary.folders, "folder"))",
                DiskFormat.bytes(tree.root.size),
                "scanned in \(DiskFormat.duration(summary.duration))",
            ]
            if model.focus != ScanTree.rootIndex, tree.contains(model.focus) {
                parts.append("\(model.displayName(of: model.focus)): \(DiskFormat.bytes(tree[model.focus].size))")
            }
            statusLine.stringValue = parts.joined(separator: " · ")
        }
    }
}
