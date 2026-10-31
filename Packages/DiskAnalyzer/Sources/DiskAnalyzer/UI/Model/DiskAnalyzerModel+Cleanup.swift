import AppKit
import SharedUI

/// Clean Up (PLAN §7.10 item 19): checks a folder and recommends the safest way to get its space back, a folder of the
/// open scan or any other (a space hog's), which gets a scan of its own. The facts are gathered off the main thread, the
/// judgment is `CleanupAdvisor`'s, and what goes goes to the Trash through the usual confirmation.
extension DiskAnalyzerModel {
    /// Checks the folder at `path`: from the open scan when it is in it, else from a scan of the folder by the window's
    /// settings, which `cancellation` stops.
    func adviseCleanup(of path: String, cancellation: CancellationFlag) async -> (facts: CleanupFacts, advice: CleanupAdvice)? {
        if let tree, let node = tree.index(ofPath: path), tree[node].kind.isContainer {
            let base = cleanupBase(path: path, flags: tree[node].flags, refusal: refusal(for: node))
            let facts = await Task.detached(priority: .userInitiated) { CleanupInspector.gather(base, node: node, in: tree) }.value
            return (facts, CleanupAdvisor.advise(facts))
        }
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue else { return nil }
        let base = cleanupBase(path: path, flags: [], refusal: safetyRules().refusal(for: path, isFolder: true)?.message)
        let options = DiskSettings.scanOptions(in: settings, firmlinks: firmlinks)
        let target = ScanTarget(
            requestedPath: path,
            scanPath: path,
            displayName: (path as NSString).lastPathComponent,
            firmlinks: firmlinks
        )
        let tree = await ScanEngine.scan(target, options: options, cancellation: cancellation).tree
        guard !cancellation.isCancelled else { return nil }
        let facts = await Task.detached(priority: .userInitiated) {
            CleanupInspector.gather(base, node: ScanTree.rootIndex, in: tree)
        }.value
        return (facts, CleanupAdvisor.advise(facts))
    }

    /// Whether Clean Up asks Apple Intelligence about a folder it does not know.
    var explainsFolders: Bool {
        settings[DiskSettings.explainsFolders] && CleanupExplainer.gate.isOpen
    }

    func explainCleanup(_ facts: CleanupFacts) async -> CleanupExplainer.Explanation? {
        guard explainsFolders else { return nil }
        return await Task.detached(priority: .userInitiated) { await CleanupExplainer.explain(facts) }.value
    }

    /// Who has something open among `paths` in `folder` now: checked again just before anything goes.
    func usersNow(of folder: String, among paths: [String]) async -> [String] {
        await Task.detached(priority: .userInitiated) {
            let wanted = Set(paths)
            return CleanupInspector.users(of: folder).filter { user in
                user.paths.contains { path in wanted.contains(path) || wanted.contains { path.hasPrefix($0 + "/") } }
            }.map(\.name)
        }.value
    }

    /// Runs a tool's own command, then says how it went.
    func runCleanup(_ command: CleanupCommand, in folder: String) {
        Task {
            let result = await ProcessRunner.run(command.executable, command.arguments)
            if result.succeeded {
                show(Message(title: "Done", text: command.done))
            } else {
                let reason = result.error.isEmpty ? result.output : result.error
                show(Message(
                    title: "“\(command.commandLine)” did not finish",
                    text: reason.isEmpty ? "It stopped with status \(result.status)." : reason
                ))
            }
            refreshFolders([folder])
            remeasureHogs(touching: [folder])
            refreshSources()
        }
    }

    /// Opens the app that cleans the folder up itself.
    func openApp(_ bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            show(Message(title: "The app is not installed", text: "No app with the ID \(bundleID) is on this Mac."))
            return
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// What the window knows about the folder: where it is, what Oriel refuses, the apps running and those its path names.
    private func cleanupBase(path: String, flags: ScanNodeFlags, refusal: String?) -> CleanupFacts {
        let home = NSHomeDirectory()
        var facts = CleanupFacts(path: path, home: home, bytes: 0, fileCount: 0, folderCount: 0, children: [])
        facts.refusal = refusal
        facts.refusesContents = flags.contains(.macOSVolume) || flags.contains(.readAsAdministrator)
            || safetyRules().refusal(for: path + "/item", isFolder: false) != nil
        facts.isUnmeasured = flags.contains(.excluded) || flags.contains(.unreadable) || flags.contains(.needsAdministrator)
        facts.isInCloud = [home + "/Library/Mobile Documents", home + "/Library/CloudStorage"].contains { path.hasPrefix($0 + "/") }
        facts.runningApps = NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, let id = app.bundleIdentifier else { return nil }
            return CleanupFacts.App(bundleID: id, name: app.localizedName ?? id, isRunning: true)
        }
        (facts.apps, facts.missingApps) = CleanupApps.named(by: path, home: home, running: facts.runningApps)
        return facts
    }
}
