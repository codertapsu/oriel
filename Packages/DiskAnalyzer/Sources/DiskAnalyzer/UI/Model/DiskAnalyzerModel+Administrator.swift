import Foundation

/// Read as Administrator: the folders of the open scan that only their owner may open, read with an administrator's
/// rights and added to the scan (`ElevatedRead`).
extension DiskAnalyzerModel {
    /// Asks macOS for an administrator's password, reads the folders as root, and adds what they hold. Oriel never sees
    /// the password; a cancelled prompt changes nothing.
    func readAsAdministrator() {
        guard let tree, !phase.isScanning, !isReadingAsAdministrator, let executable = Bundle.main.executablePath else { return }
        var nodes = tree.descendants(of: ScanTree.rootIndex) { $0.flags.contains(.needsAdministrator) }.sorted()
        if tree.root.flags.contains(.needsAdministrator) {
            nodes.insert(ScanTree.rootIndex, at: 0)
        }
        guard !nodes.isEmpty else { return }
        let folders = nodes.prefix(ElevatedRead.folderLimit).map(tree.path(of:))
        let options = DiskSettings.scanOptions(in: settings, firmlinks: firmlinks)
        let flag = cancellation
        isReadingAsAdministrator = true
        log.info("Reading \(folders.count) folders as an administrator")
        Task {
            let outcome = await ElevatedRead.run(folders: folders, options: options, executable: executable)
            guard flag === cancellation else { return }
            switch outcome {
            case .cancelled:
                isReadingAsAdministrator = false
            case let .failed(reason):
                isReadingAsAdministrator = false
                show(Message(title: "The folders could not be read as an administrator", text: reason))
            case let .read(result):
                serially { await self.add(result, folders: folders, flag: flag) }
            }
        }
    }

    /// Puts what Read as Administrator found into the open scan, and sums its totals, its summary and the volume's blocks
    /// again.
    private func add(_ result: ElevatedRead.Result, folders: [String], flag: CancellationFlag?) async {
        defer { isReadingAsAdministrator = false }
        guard let tree, let summary, flag === cancellation else { return }
        let volume = target?.volume
        let updated = await Task.detached(priority: .userInitiated) { [tree, summary] in
            var tree = tree
            var summary = summary
            let dirty = ElevatedRead.apply(result, folders: folders, to: &tree, summary: &summary)
            tree.recomputeTotals(dirty: dirty)
            tree.finishBuilding()
            if let volume {
                tree = Self.addingVolumeBlocks(to: tree, volume: volume)
            }
            summary.files = Int(tree.root.fileCount)
            summary.folders = Int(tree.root.folderCount)
            summary.bytes = tree.root.size
            summary.logicalBytes = tree.root.logicalSize
            summary.recountUnreadable(in: tree)
            return (tree, summary)
        }.value
        guard flag === cancellation else { return }
        adopt(updated.0)
        self.summary = updated.1
        log.info("Read \(result.listings.count) folders as an administrator")
    }
}
