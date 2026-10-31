import AppKit

/// Read as Administrator: the folders of the open scan that only their owner may open, read with an administrator's
/// rights and added to the scan (`ElevatedRead`), through Oriel's helper once the user has allowed it
/// (`PrivilegedReader`), else through macOS's password prompt.
extension DiskAnalyzerModel {
    /// How the folders are read as root.
    enum AdministratorRoute {
        /// Oriel's helper, allowed once in System Settings: no password.
        case helper
        /// macOS's password prompt, for this read only.
        case password
    }

    /// Reads the folders that need an administrator and adds what they hold. A read through the helper that fails falls
    /// back to the password prompt, unless it was `automatic` (after a scan), when the note stays instead.
    func readAsAdministrator(through route: AdministratorRoute, automatic: Bool = false) {
        guard let tree, !phase.isScanning, !isReadingAsAdministrator, let executable = Bundle.main.executablePath else { return }
        var nodes = tree.descendants(of: ScanTree.rootIndex) { $0.flags.contains(.needsAdministrator) }.sorted()
        if tree.root.flags.contains(.needsAdministrator) {
            nodes.insert(ScanTree.rootIndex, at: 0)
        }
        guard !nodes.isEmpty else { return }
        let folders = nodes.prefix(ElevatedRead.folderLimit).map(tree.path(of:))
        let request = ElevatedRead.Request(folders: folders, options: DiskSettings.scanOptions(in: settings, firmlinks: firmlinks))
        let flag = cancellation
        isReadingAsAdministrator = true
        log.info("Reading \(folders.count) folders as an administrator")
        Task {
            var outcome = route == .helper ? await readThroughHelper(request) : .failed("")
            if route == .password || (!automatic && outcome.failed) {
                outcome = await ElevatedRead.runWithPassword(request, executable: executable)
            }
            guard flag === cancellation else { return }
            switch outcome {
            case .cancelled:
                isReadingAsAdministrator = false
            case let .failed(reason):
                isReadingAsAdministrator = false
                if automatic {
                    refreshHelperStatus()
                } else {
                    show(Message(title: "The folders could not be read as an administrator", text: reason))
                }
            case let .read(result):
                serially { await self.add(result, folders: folders, flag: flag) }
            }
        }
    }

    /// After a complete scan, when the helper is allowed: reads those folders without asking.
    func readAsAdministratorAfterScan() {
        guard helperStatus == .allowed, settings[DiskSettings.readsAsAdministrator], (summary?.administratorFolders ?? 0) > 0 else {
            return
        }
        readAsAdministrator(through: .helper, automatic: true)
    }

    // MARK: The helper

    /// Registers the helper and opens Login Items, where the user switches it on; once it is allowed, the open scan's
    /// folders are read.
    func installHelper() {
        Task {
            let failure = await Task.detached(priority: .userInitiated) { () -> String? in
                do {
                    try PrivilegedReader.install()
                    return nil
                } catch {
                    return error.localizedDescription
                }
            }.value
            if let failure {
                show(Message(title: "Oriel's helper could not be installed", text: failure))
                return
            }
            settings[DiskSettings.helperBuild] = PrivilegedReader.build
            approveHelper()
        }
    }

    /// Opens Login Items for the user to switch the helper on, and reads the open scan's folders once it is allowed.
    func approveHelper() {
        readsAfterHelperApproval = true
        PrivilegedReader.openLoginItems()
        refreshHelperStatus()
    }

    /// Reads the helper's state again: when the window opens, whenever Oriel comes to the front, as after a visit to
    /// System Settings, and when Settings installs or removes it. Nothing polls.
    func refreshHelperStatus() {
        Task {
            let status = await Task.detached(priority: .utility) { PrivilegedReader.status }.value
            helperStatus = status
            if status == .allowed, readsAfterHelperApproval {
                readsAfterHelperApproval = false
                readAsAdministrator(through: .helper)
            }
        }
    }

    /// Reads through the helper while macOS says it is allowed, registering it again first after an update. A request
    /// whose connection failed is sent once more, for a helper that was just exiting, and then once after registering it
    /// again. One the helper did not finish in time is not: it would be read twice at once, or the helper killed.
    private func readThroughHelper(_ request: ElevatedRead.Request) async -> ElevatedRead.Outcome {
        guard await helperIsAllowed() else { return .failed("Oriel's helper is not allowed.") }
        if settings[DiskSettings.helperBuild] != PrivilegedReader.build {
            if let failure = await reinstallHelper() {
                return failure
            }
            settings[DiskSettings.helperBuild] = PrivilegedReader.build
        }
        var answer = await PrivilegedReader.read(request)
        if answer.connectionFailed {
            answer = await PrivilegedReader.read(request)
        }
        guard answer.connectionFailed, await helperIsAllowed() else { return answer.outcome }
        log.error("Oriel's helper could not be reached; registering it again")
        if let failure = await reinstallHelper() {
            return failure
        }
        return await PrivilegedReader.read(request).outcome
    }

    /// Registers the helper again; why not, when macOS refuses, which leaves it unregistered.
    private func reinstallHelper() async -> ElevatedRead.Outcome? {
        do {
            try await PrivilegedReader.reinstall()
            return nil
        } catch {
            log.error("Oriel's helper could not be registered again: \(error.localizedDescription, privacy: .public)")
            _ = await helperIsAllowed()
            return .failed("Oriel's helper could not be registered again: \(error.localizedDescription)")
        }
    }

    /// Asks macOS for the helper's state before using or registering it, as `SMAppService`'s header advises: the window's
    /// may be old, since Remove Helper in Settings and Login Items change it without telling the window, and registering
    /// a helper the user removed or switched off would add it back.
    private func helperIsAllowed() async -> Bool {
        helperStatus = await Task.detached(priority: .userInitiated) { PrivilegedReader.status }.value
        return helperStatus == .allowed
    }

    /// Puts what was read into the open scan.
    private func add(_ result: ElevatedRead.Result, folders: [String], flag: CancellationFlag?) async {
        defer { isReadingAsAdministrator = false }
        guard let tree, let summary, flag === cancellation else { return }
        let volume = target?.volume
        let updated = await Task.detached(priority: .userInitiated) { [tree, summary] in
            Self.adding(result, folders: folders, to: tree, summary: summary, volume: volume)
        }.value
        guard flag === cancellation else { return }
        adopt(updated.tree)
        self.summary = updated.summary
        log.info("Read \(result.listings.count) folders as an administrator")
    }

    /// A tree and summary with what Read as Administrator found in them: totals, the summary and the volume's blocks
    /// summed again (`recounting`).
    nonisolated static func adding(
        _ result: ElevatedRead.Result,
        folders: [String],
        to tree: ScanTree,
        summary: ScanSummary,
        volume: VolumeInfo?
    ) -> (tree: ScanTree, summary: ScanSummary) {
        var tree = tree
        var summary = summary
        let dirty = ElevatedRead.apply(result, folders: folders, to: &tree, summary: &summary)
        tree.recomputeTotals(dirty: dirty)
        tree.finishBuilding()
        return recounting(tree, summary: summary, volume: volume)
    }
}

nonisolated extension ElevatedRead.Outcome {
    var failed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}
