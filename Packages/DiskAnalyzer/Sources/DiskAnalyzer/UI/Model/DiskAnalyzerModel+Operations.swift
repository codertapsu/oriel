import AppKit
import SharedUI

/// File operations on what the scan shows: planned for a confirmation, run with progress, the tree updated after.
extension DiskAnalyzerModel {
    /// What a confirmation names and what then runs.
    struct Plan: Equatable {
        var operation: FileOperation
        var nodes: [Int32]
        var names: [String]
        /// Bytes on disk for a removal (what it frees), content bytes for a copy or move (what it writes).
        var bytes: Int64

        var count: Int {
            nodes.count
        }
    }

    func plan(_ kind: FileOperation.Kind, nodes: [Int32]) -> Plan? {
        guard let tree else { return nil }
        // The scanned folder itself is never part of a plan, so it cannot hide what is selected inside it.
        let set = Set(nodes).subtracting([ScanTree.rootIndex])
        let topmost = nodes.filter { node in
            tree.contains(node) && !tree[node].kind.isSynthetic && node != ScanTree.rootIndex
                && !tree.lineage(of: node).dropLast().contains(where: set.contains)
        }
        guard !topmost.isEmpty else { return nil }
        let bytes = topmost.reduce(Int64(0)) { $0 + (kind.isDestructive ? tree[$1].size : tree[$1].logicalSize) }
        let operation = FileOperation(kind: kind, items: topmost.map(url(of:)), totalBytes: bytes)
        return Plan(operation: operation, nodes: topmost, names: topmost.map(displayName(of:)), bytes: bytes)
    }

    /// The rules every removal and move goes through.
    func safetyRules() -> SafetyRules {
        SafetyRules(
            home: NSHomeDirectory(),
            volumeRoots: VolumeService.allMountPoints(),
            appBundle: Bundle.main.bundleURL.pathExtension == "app" ? Bundle.main.bundlePath : nil,
            firmlinks: firmlinks,
            temporaryFolder: NSTemporaryDirectory()
        )
    }

    /// Why an item may not be removed or moved, for the context menu and the inspector; nil if it may.
    func refusal(for node: Int32) -> String? {
        guard let tree, tree.contains(node) else { return nil }
        if node == ScanTree.rootIndex {
            return "It is the folder you scanned."
        }
        guard !tree[node].kind.isSynthetic else { return "It is not a file or folder." }
        if tree[node].flags.contains(.macOSVolume) {
            return SafetyRules.Refusal.system.message
        }
        if tree[node].flags.contains(.readAsAdministrator) {
            return "Only its owner, macOS or another user, may change it. Oriel read it as an administrator and changes nothing."
        }
        let destination = tree[node].kind == .symlink ? try? FileManager.default
            .destinationOfSymbolicLink(atPath: displayPath(of: node)) : nil
        return safetyRules().refusal(for: displayPath(of: node), isFolder: tree[node].kind.isContainer, symlinkDestination: destination)?
            .message
    }

    func run(_ plan: Plan) {
        guard operation == nil else { return }
        let flag = CancellationFlag()
        operationCancellation = flag
        let fileOperator = FileOperator(rules: safetyRules())
        var start = FileOperationProgress()
        start.totalItems = plan.count
        start.totalBytes = plan.operation.kind.isDestructive ? 0 : plan.bytes
        operation = OperationState(kind: plan.operation.kind, progress: start)
        Task {
            let report = await fileOperator.run(plan.operation, cancellation: flag) { progress in
                Task { @MainActor in
                    guard self.operationCancellation === flag else { return }
                    self.operation?.progress = progress
                }
            }
            operation = nil
            operationCancellation = nil
            finish(plan, report: report)
        }
    }

    func cancelOperation() {
        operationCancellation?.cancel()
    }

    private func finish(_ plan: Plan, report: FileOperationReport) {
        let done = Set(report.completed)
        let removed = plan.nodes.filter { done.contains(url(of: $0)) }
        switch plan.operation.kind {
        case .trash, .delete, .move:
            remove(removed)
        case .copy:
            break
        }
        if case let .copy(folder) = plan.operation.kind {
            refreshFolders([folder.path])
        } else if case let .move(folder) = plan.operation.kind {
            refreshFolders([folder.path])
        } else if plan.operation.kind.isDestructive, plan.nodes.count < plan.operation.items.count {
            // Some items were not nodes of the scan (smaller files it summed up): their folders are read again.
            refreshFolders(Array(Set(plan.operation.items.map { $0.deletingLastPathComponent().path })))
        }
        if !report.trashed.isEmpty {
            registerUndo(of: report.trashed)
        }
        if plan.operation.kind.takesItemsAway {
            remeasureHogs(touching: report.completed.map(\.path))
        }
        if report.hasProblems {
            show(problems(in: report, kind: plan.operation.kind))
        } else if !report.wasCancelled {
            Toast.show(summary(of: plan, report: report), symbol: plan.operation.kind == .trash ? "trash" : "checkmark.circle")
        }
        refreshSources()
    }

    /// Takes removed items out of the tree, off the main thread for a big one, after the edits before.
    func remove(_ nodes: [Int32]) {
        guard !nodes.isEmpty else { return }
        let flag = cancellation
        serially { [weak self] in
            guard let self, let tree, flag === cancellation else { return }
            let updated = await Task.detached(priority: .userInitiated) {
                var tree = tree
                for node in nodes {
                    tree.remove(node)
                }
                return tree
            }.value
            guard flag === cancellation, self.tree?.generation == tree.generation else { return }
            adopt(updated)
            summary?.bytes = updated.root.size
        }
    }

    /// Reads the folders at `paths` again, if they are part of the scan: after a copy or move into them, which
    /// FSEvents does not report because Oriel made it.
    func refreshFolders(_ paths: [String]) {
        guard let tree else { return }
        let inside = paths.filter { tree.index(ofPath: $0) != nil }
        guard !inside.isEmpty else { return }
        filesChanged(ScanWatcher.Change(folders: inside, deepFolders: [], rootChanged: false))
    }

    private func registerUndo(of items: [TrashedItem]) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated { model.restore(items) }
        }
        undoManager.setActionName(items.count == 1 ? "Move to Trash" : "Move \(items.count) Items to Trash")
    }

    /// Undo: puts trashed items back and reads their folders again.
    func restore(_ items: [TrashedItem]) {
        let fileOperator = FileOperator(rules: safetyRules())
        Task {
            let failures = await fileOperator.restore(items)
            refreshFolders(items.map { $0.original.deletingLastPathComponent().path })
            refreshSources()
            if !failures.isEmpty {
                show(Message(
                    title: "Some items stayed in the Trash",
                    text: failures.map { "“\($0.url.lastPathComponent)”: \($0.message)" }
                        .joined(separator: "\n")
                ))
            }
        }
    }

    private func problems(in report: FileOperationReport, kind: FileOperation.Kind) -> Message {
        let lines = (report.refused + report.failures).prefix(8).map { "“\($0.url.lastPathComponent)”: \($0.message)" }
        let more = report.refused.count + report.failures.count - lines.count
        var text = lines.joined(separator: "\n")
        if more > 0 {
            text += "\nand \(DiskFormat.count(more, "other item")) more."
        }
        let done = report.completed.count
        let title = done == 0 ? "Nothing was \(kind.pastTense)" : "\(DiskFormat.count(done, "item")) \(kind.pastTense), some not"
        return Message(title: title, text: text)
    }

    private func summary(of plan: Plan, report: FileOperationReport) -> String {
        let done = report.completed.count
        switch plan.operation.kind {
        case .trash: return "Moved \(DiskFormat.count(done, "item")) to the Trash"
        case .delete: return "Deleted \(DiskFormat.count(done, "item")), \(DiskFormat.bytes(plan.bytes))"
        case .copy: return "Copied \(DiskFormat.count(done, "item"))"
        case .move: return "Moved \(DiskFormat.count(done, "item"))"
        }
    }

    // MARK: Volumes and iCloud

    /// Ejects a volume; the scan of it goes with it.
    func eject(_ volume: VolumeInfo) {
        let url = volume.url
        Task {
            do {
                // Unmounting waits for the disk; it must not hold up the window.
                try await Task.detached(priority: .userInitiated) { try NSWorkspace.shared.unmountAndEjectDevice(at: url) }.value
                if target?.volume?.path == volume.path || target.map({ $0.requestedPath.hasPrefix(volume.path + "/") }) == true {
                    windowClosed()
                    windowOpened()
                }
                if source?.path == volume.path {
                    source = nil
                }
            } catch {
                show(Message(title: "“\(volume.name)” could not be ejected", text: error.localizedDescription))
            }
            refreshSources()
        }
    }

    /// Removes the local copies of iCloud Drive items; they stay in iCloud and download again when opened.
    func removeDownloads(_ nodes: [Int32]) {
        let urls = nodes.filter(canRemoveDownload).map(url(of:))
        guard !urls.isEmpty else { return }
        Task {
            let failures = await Task.detached(priority: .userInitiated) {
                urls.compactMap { url -> String? in
                    do {
                        try FileManager.default.evictUbiquitousItem(at: url)
                        return nil
                    } catch {
                        return "“\(url.lastPathComponent)”: \(FileErrorMessage.message(for: error))"
                    }
                }
            }.value
            refreshFolders(urls.map { $0.deletingLastPathComponent().path })
            if !failures.isEmpty {
                show(Message(title: "Some downloads were not removed", text: failures.joined(separator: "\n")))
            }
        }
    }
}
