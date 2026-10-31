import Foundation

/// Scanning, and keeping the open scan in step with the disk.
extension DiskAnalyzerModel {
    /// Starts a scan of `path`, a volume's mount point or a folder, stopping the one running.
    func scan(path: String) {
        cancellation?.cancel()
        watcher.stop()
        refreshDelay?.cancel()
        let flag = CancellationFlag()
        cancellation = flag
        let path = ExclusionRules.normalize(path, home: NSHomeDirectory())
        let dataVolume = FileManager.default.fileExists(atPath: FirmlinkMap.dataVolume)
        let target = ScanTarget.resolve(
            path: path,
            volumes: volumes,
            dataVolumeExists: dataVolume,
            firmlinks: firmlinks,
            macOSVolumes: settings[DiskSettings.countsMacOSFiles] ? MacOSVolumes.startup(helperMounts: helperMounts) : nil
        )
        let options = DiskSettings.scanOptions(in: settings, firmlinks: firmlinks)
        self.target = target
        source = source(for: target)
        tree = nil
        summary = nil
        diff = nil
        duplicates = .idle
        duplicateMarks = []
        lastOpened = [:]
        askedLastOpened = []
        hiddenNotes = []
        isReadingAsAdministrator = false
        hogs = [:]
        selection = []
        focus = ScanTree.rootIndex
        phase = .scanning(ScanProgress())
        treeVersion += 1
        log.info("Scanning \(target.scanPath, privacy: .private)")
        scanTask = Task { [weak self] in
            let outcome = await ScanEngine.scan(target, options: options, cancellation: flag) { progress in
                Task { @MainActor in self?.progressed(progress, flag: flag) }
            }
            await self?.finish(outcome, target: target, flag: flag)
        }
    }

    /// Scans the open scan's folder again from scratch.
    func rescan() {
        guard let target else { return }
        scan(path: target.requestedPath)
    }

    /// Stops the scan; what was read so far stays, marked partial.
    func stopScan() {
        cancellation?.cancel()
    }

    private func source(for target: ScanTarget) -> DiskSource {
        if volumes.contains(where: { $0.path == target.requestedPath }) {
            return .volume(target.requestedPath)
        }
        if clouds.contains(where: { $0.path == target.requestedPath }) {
            return .cloud(target.requestedPath)
        }
        return .folder(target.requestedPath)
    }

    private func progressed(_ progress: ScanProgress, flag: CancellationFlag) {
        guard flag === cancellation, phase.isScanning, !flag.isCancelled else { return }
        phase = .scanning(progress)
    }

    private func finish(_ outcome: ScanEngine.Outcome, target: ScanTarget, flag: CancellationFlag) async {
        guard flag === cancellation else { return }
        var tree = outcome.tree
        if let volume = target.volume, !outcome.summary.wasCancelled {
            tree = await Task.detached(priority: .userInitiated) { [tree] in Self.addingVolumeBlocks(to: tree, volume: volume) }.value
        }
        guard flag === cancellation else { return }
        summary = outcome.summary
        adopt(tree)
        phase = .ready(stopped: outcome.summary.wasCancelled)
        log.info("Scanned \(outcome.summary.files) files in \(outcome.summary.duration.formatted(), privacy: .public)")
        guard !outcome.summary.wasCancelled else { return }
        if settings[DiskSettings.watchesChanges] {
            watcher.start(path: target.scanPath)
        }
        if settings[DiskSettings.remembersScans] {
            remember(tree, target: target, flag: flag)
        }
        readAsAdministratorAfterScan()
    }

    /// Adds the startup volume's system block, unless macOS's own volumes were read file by file, and the used space no
    /// file accounts for, so a volume's scan adds up to what Finder calls used. Blocks added before are replaced.
    nonisolated static func addingVolumeBlocks(to tree: ScanTree, volume: VolumeInfo) -> ScanTree {
        var tree = tree
        for block in tree.children(of: ScanTree.rootIndex) where tree[block].kind == .system || tree[block].kind == .unaccounted {
            tree.remove(block)
        }
        let fresh = VolumeService.info(for: volume.url)?.usage ?? volume.usage
        let system = volume.kind == .startup && !tree.hasMacOSVolumes ? VolumeService.systemBytes() : 0
        let blocks = VolumeAccounting.blocks(volumeUsed: fresh.used, scanned: tree.root.size, system: system)
        if blocks.system > 0 {
            tree.appendSynthetic(.system, name: "macOS (system)", size: blocks.system)
        }
        if blocks.unaccounted > 0 {
            tree.appendSynthetic(.unaccounted, name: "Other space", size: blocks.unaccounted)
        }
        tree.recomputeTotals(dirty: [ScanTree.rootIndex])
        tree.finishBuilding()
        return tree
    }

    /// A tree and summary after an edit of the tree, summed again as the scan summed them: the volume's blocks for a
    /// complete scan of a whole volume (`addingVolumeBlocks`), so it still adds up to the volume's used space, then the
    /// summary's counts, its file types, further links, files only in the cloud and entries that could not be read, and the
    /// folders still closed, from the tree.
    nonisolated static func recounting(
        _ tree: ScanTree,
        summary: ScanSummary,
        volume: VolumeInfo?
    ) -> (tree: ScanTree, summary: ScanSummary) {
        var tree = tree
        var summary = summary
        if let volume, !summary.wasCancelled {
            tree = addingVolumeBlocks(to: tree, volume: volume)
        }
        summary.files = Int(tree.root.fileCount)
        summary.folders = Int(tree.root.folderCount)
        summary.bytes = tree.root.size
        summary.logicalBytes = tree.root.logicalSize
        summary.recountListings(in: tree)
        summary.recountUnreadable(in: tree)
        return (tree, summary)
    }

    /// Saves a summary of the scan and works out what grew since the one before.
    private func remember(_ tree: ScanTree, target: ScanTarget, flag: CancellationFlag) {
        let store = store
        Task {
            let snapshot = await Task.detached(priority: .utility) {
                ScanSnapshot.make(from: tree, rootPath: target.requestedPath, displayName: target.displayName, date: Date())
            }.value
            let previous = await store.previous(of: target.requestedPath, excluding: snapshot.id)
            records = await store.save(snapshot)
            guard let previous else { return }
            let diff = await Task.detached(priority: .utility) { SnapshotDiff.between(previous, snapshot) }.value
            if flag === cancellation {
                self.diff = diff
            }
        }
    }

    /// Forgets the remembered scans of `path`.
    func forgetScans(of path: String) {
        let store = store
        Task {
            records = await store.remove(rootPath: path)
            if source == .folder(path), target?.requestedPath != path {
                source = nil
            }
        }
    }

    /// The previous scan of the open folder, for the Changes sheet.
    func previousSnapshot() async -> ScanSnapshot? {
        guard let target else { return nil }
        let latest = records.filter { $0.rootPath == target.requestedPath }.max { $0.date < $1.date }
        return await store.previous(of: target.requestedPath, excluding: latest?.id)
    }

    // MARK: Changes on disk

    func filesChanged(_ change: ScanWatcher.Change) {
        guard tree != nil, !phase.isScanning, let target else { return }
        pendingFolders.formUnion(change.folders)
        pendingDeepFolders.formUnion(change.deepFolders)
        if change.rootChanged {
            pendingDeepFolders.insert(target.scanPath)
        }
        // Wait for a quiet moment: a download or a build changes many folders in a row.
        refreshDelay?.cancel()
        refreshDelay = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.applyPendingChanges()
        }
    }

    private func applyPendingChanges() {
        let folders = pendingFolders
        let deep = pendingDeepFolders
        pendingFolders = []
        pendingDeepFolders = []
        let options = DiskSettings.scanOptions(in: settings, firmlinks: firmlinks)
        let flag = cancellation
        serially { [weak self] in
            guard let self, let tree, flag === cancellation else { return }
            let shallow = Set(folders.compactMap(tree.nearestIndex(toPath:)))
            let recursive = Set(deep.compactMap(tree.nearestIndex(toPath:)))
            guard !shallow.isEmpty || !recursive.isEmpty else { return }
            let outcome = await ScanEngine.refresh(
                tree,
                folders: shallow,
                recursive: recursive,
                options: options,
                cancellation: CancellationFlag()
            )
            // Summed again as the scan summed it: the volume's blocks, since the files changed, and the summary, whose
            // folders still closed, Read as Administrator's among them, give the notes about them.
            let volume = target?.volume
            let (updated, counted) = await Task.detached(priority: .utility) { [summary] in
                let refreshed = outcome.tree.needsCompaction ? outcome.tree.compacted() : outcome.tree
                let recounted = summary.map { Self.recounting(refreshed, summary: $0, volume: volume) }
                return (recounted?.tree ?? refreshed, recounted?.summary)
            }.value
            guard flag === cancellation, self.tree?.generation == tree.generation else { return }
            adopt(updated)
            summary = counted
        }
    }
}
