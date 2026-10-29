import Foundation

/// The analyses beyond the tree: duplicates, space hogs, Spotlight dates, local snapshots and simulators.
extension DiskAnalyzerModel {
    // MARK: Duplicates

    /// Looks for duplicates among the files below the current folder that the scan kept one by one.
    func findDuplicates() {
        guard let tree else { return }
        duplicateCancellation?.cancel()
        let flag = CancellationFlag()
        duplicateCancellation = flag
        let folder = focus
        let minimum = max(Int64(settings[DiskSettings.smallFileThreshold]), 1_000_000)
        duplicates = .searching(nil)
        duplicateMarks = []
        Task {
            let candidates = await Task.detached(priority: .userInitiated) {
                DuplicateFinder.candidates(in: tree, under: folder, minimumSize: minimum)
            }.value
            let groups = await DuplicateFinder.find(candidates, minimumSize: minimum, cancellation: flag) { progress in
                Task { @MainActor in
                    guard self.duplicateCancellation === flag, case .searching = self.duplicates else { return }
                    self.duplicates = .searching(progress)
                }
            }
            guard duplicateCancellation === flag else { return }
            duplicates = flag.isCancelled ? .idle : .found(groups, folder: folder)
        }
    }

    func cancelDuplicates() {
        duplicateCancellation?.cancel()
        duplicates = .idle
    }

    /// Marks every copy but the newest (or oldest) of each group.
    func markAllButOne(keeping keep: DuplicateSelection.Keep) {
        guard let tree, case let .found(groups, _) = duplicates else { return }
        duplicateMarks = DuplicateSelection.allButOne(
            groups, keep: keep, modified: { tree[$0].modifiedDate }, path: { tree.path(of: $0) }
        )
    }

    // MARK: Space hogs

    func measureHogs() {
        let home = NSHomeDirectory()
        let tree = tree
        for hog in SpaceHogCatalog.all {
            hogs[hog.id] = .measuring
        }
        Task {
            for hog in SpaceHogCatalog.all {
                let result = await SpaceHogMeter.measure(hog, home: home, tree: tree)
                hogs[hog.id] = result
            }
        }
    }

    var hasMeasuredHogs: Bool {
        !hogs.isEmpty
    }

    /// Runs a hog's action on what was found; removals go through the usual confirmation first (`plan(paths:)`).
    func deleteUnavailableSimulators() {
        Task {
            let result = await Simulators.deleteUnavailable()
            if result.succeeded {
                show(Message(
                    title: "Unavailable simulators deleted",
                    text: "Simulators for runtimes that are no longer installed are gone."
                ))
            } else {
                show(Message(title: "Simulators were not deleted", text: result.error.isEmpty ? "simctl did not finish." : result.error))
            }
            if let hog = SpaceHogCatalog.all.first(where: { $0.action == .deleteUnavailableSimulators }) {
                hogs[hog.id] = await SpaceHogMeter.measure(hog, home: NSHomeDirectory(), tree: tree)
            }
            refreshSources()
        }
    }

    /// A plan for paths outside the scan, such as a space hog's contents.
    func plan(_ kind: FileOperation.Kind, paths: [String], bytes: Int64) -> Plan? {
        guard !paths.isEmpty else { return nil }
        let urls = paths.map { URL(fileURLWithPath: $0) }
        let operation = FileOperation(kind: kind, items: urls, totalBytes: bytes)
        let nodes = tree.map { tree in paths.compactMap(tree.index(ofPath:)) } ?? []
        return Plan(operation: operation, nodes: nodes, names: urls.map(\.lastPathComponent), bytes: bytes)
    }

    // MARK: Spotlight dates

    /// Asks Spotlight when `nodes` were last opened, those not asked about yet; Old Files shows the answers.
    func loadLastOpened(for nodes: [Int32]) {
        guard settings[DiskSettings.usesSpotlightDates], let tree else { return }
        let missing = nodes.filter { lastOpened[$0] == nil && !askedLastOpened.contains($0) }
        guard !missing.isEmpty else { return }
        askedLastOpened.formUnion(missing)
        let paths = missing.map { (node: $0, path: tree.displayPath(of: $0)) }
        let flag = cancellation ?? CancellationFlag()
        Task {
            let dates = await Task.detached(priority: .utility) { LastOpenedDates.dates(of: paths, cancellation: flag) }.value
            guard flag === cancellation, !dates.isEmpty else { return }
            lastOpened.merge(dates) { $1 }
        }
    }

    // MARK: Local snapshots

    /// Lists a volume's local snapshots, once, when its overview first shows.
    func loadLocalSnapshots(of volume: VolumeInfo) {
        guard volume.canHaveLocalSnapshots, localSnapshotLoads.insert(volume.path).inserted else { return }
        Task {
            localSnapshots[volume.path] = await LocalSnapshots.list(volume: volume.path) ?? []
        }
    }

    func thinLocalSnapshots(of volume: VolumeInfo) {
        Task {
            switch await LocalSnapshots.thin(volume: volume.path, bytes: volume.usage.total) {
            case let .thinned(count):
                let text = count == 0 ? "macOS kept the snapshots it still needs." : "\(DiskFormat.count(count, "snapshot")) removed."
                show(Message(title: "Local snapshots thinned", text: text))
            case let .failed(reason):
                show(Message(title: "Local snapshots were not thinned", text: reason))
            case .cancelled:
                break
            }
            localSnapshots[volume.path] = await LocalSnapshots.list(volume: volume.path) ?? []
            refreshSources()
        }
    }
}
