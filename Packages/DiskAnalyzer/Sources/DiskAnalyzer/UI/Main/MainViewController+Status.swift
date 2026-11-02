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
        notes += unreadableNotes(summary)
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

    /// Why folders could not be read, each with what helps: Full Disk Access lifts macOS's privacy protection, but not a
    /// folder's permissions, which only an administrator gets past (docs/os-quirks.md).
    private func unreadableNotes(_ summary: ScanSummary) -> [Note] {
        var notes: [Note] = []
        let administrator = summary.administratorFolders
        if model.isReadingAsAdministrator {
            notes.append(Note(
                id: "administrator",
                symbol: "lock.open",
                tint: .controlAccentColor,
                text: "Reading \(DiskFormat.count(administrator, "folder")) as an administrator…"
            ))
        } else if administrator > 0, !model.canReadAsAdministrator {
            // The App Store edition cannot read them at all (PLAN §19).
            notes.append(Note(
                id: "administrator",
                symbol: "lock",
                tint: .secondaryLabelColor,
                text: "\(DiskFormat.count(administrator, "folder")) can be opened only by macOS or another user, so "
                    + "\(administrator == 1 ? "its" : "their") space is not counted."
            ))
        } else if administrator > 0 {
            notes.append(Note(
                id: "administrator",
                symbol: "lock",
                tint: .systemOrange,
                text: "\(DiskFormat.count(administrator, "folder")) can be opened only by macOS or another user, so "
                    + "\(administrator == 1 ? "its" : "their") space is not counted. Full Disk Access does not change that.",
                button: "Read as Administrator…"
            ) { [weak self] in self?.actions?.readAsAdministrator() })
        }
        let protected = summary.protectedFolders
        if protected > 0, model.hasFullDiskAccess == true {
            // Full Disk Access has opened what it can: the rest is closed to every app.
            notes.append(Note(
                id: "protected",
                symbol: "lock.shield",
                tint: .secondaryLabelColor,
                text: "\(DiskFormat.count(protected, "folder")) \(protected == 1 ? "is" : "are") kept from every app by macOS, "
                    + "Full Disk Access and administrators included: System Integrity Protection guards its own data there."
            ))
        } else if protected > 0 {
            notes.append(Note(
                id: "protected",
                symbol: "lock.shield",
                tint: .secondaryLabelColor,
                text: "\(DiskFormat.count(protected, "folder")) \(protected == 1 ? "is" : "are") protected by macOS. Full Disk "
                    + "Access opens personal data such as Mail; System Integrity Protection keeps the rest from every app.",
                button: "Full Disk Access…"
            ) { SystemLinks.open(SystemLinks.fullDiskAccess) })
        }
        let others = summary.unreadableFolders - administrator - protected
        if others > 0 {
            notes.append(Note(
                id: "unreadable",
                symbol: "exclamationmark.triangle",
                tint: .systemOrange,
                text: "\(DiskFormat.count(others, "folder")) could not be read, so \(others == 1 ? "its" : "their") space is not counted."
            ))
        }
        return notes
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
