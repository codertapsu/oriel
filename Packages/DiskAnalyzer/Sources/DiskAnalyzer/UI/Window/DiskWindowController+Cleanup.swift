import AppKit
import OrielCore
import SharedUI

/// Clean Up (PLAN §7.10 item 19): the sheet, and carrying out what the user chose, for a folder of the scan or any other
/// (a space hog's). Whatever goes is checked for processes using it before the usual confirmation, and again after it,
/// then goes to the Trash.
extension DiskWindowController {
    func cleanUp(_ node: Int32) {
        guard let tree = model.tree, tree.contains(node), tree[node].kind.isContainer else { return }
        let path = model.displayPath(of: node)
        cleanUp(path: path, icon: NodeIcons().icon(for: node, in: tree) { path })
    }

    func cleanUp(path: String) {
        cleanUp(path: path, icon: NSWorkspace.shared.icon(forFile: path))
    }

    private func cleanUp(path: String, icon: NSImage) {
        guard let window, ProAccess.shared.check(.cleanUp) else { return }
        let sheet = CleanupSheetController(name: (path as NSString).lastPathComponent, path: path, icon: icon)
        cleanupSheet = sheet
        sheet.onChoose = { [weak self] method, facts in
            // Let the sheet go before a confirmation comes.
            Task { @MainActor in self?.carryOut(method, facts: facts) }
        }
        sheet.onReveal = { SystemLinks.reveal([URL(fileURLWithPath: path)]) }
        sheet.onQuit = { [weak self] apps in self?.quit(apps, thenCheck: path) }
        window.beginSheet(sheet.panel) { [weak self] _ in
            guard let self, cleanupSheet === sheet else { return }
            cleanupCancellation?.cancel()
            cleanupCancellation = nil
            cleanupSheet = nil
            stopWaitingForApps()
        }
        check(path, in: sheet)
    }

    /// The advice, then Apple Intelligence's reading for a folder Oriel does not know, which can only make it more careful.
    /// A newer check (after an app quit) replaces this one: its scan stops and its results are dropped.
    private func check(_ path: String, in sheet: CleanupSheetController) {
        cleanupCheck += 1
        let generation = cleanupCheck
        cleanupCancellation?.cancel()
        let cancellation = CancellationFlag()
        cleanupCancellation = cancellation
        let isCurrent = { [weak self] in self?.cleanupSheet === sheet && self?.cleanupCheck == generation }
        Task {
            let result = await model.adviseCleanup(of: path, cancellation: cancellation)
            guard isCurrent() else { return }
            guard let (facts, advice) = result else {
                sheet.close()
                present(.init(
                    title: "“\((path as NSString).lastPathComponent)” is no longer there",
                    text: "It was moved or removed, or it is no longer a folder."
                ))
                return
            }
            let explaining = !advice.isKnown && model.explainsFolders
            sheet.show(advice, facts: facts, explaining: explaining)
            guard explaining else { return }
            let reading = await model.explainCleanup(facts)
            guard isCurrent() else { return }
            var advised = advice
            if let reading, reading.mayLoseData, advised.verdict < .careful {
                advised.raise(to: .careful)
                advised.findings.append(.init(
                    .warning,
                    "Apple Intelligence thinks removing it could lose something that cannot be rebuilt."
                ))
            }
            sheet.show(reading, advice: advised)
        }
    }

    private func carryOut(_ method: CleanupMethod, facts: CleanupFacts) {
        switch method.action {
        case .trashFolder:
            let recheck = inUseCheck([facts.path], in: facts.path)
            Task {
                guard await recheck() else { return }
                // Looked up only now: the tree may have changed while the check ran.
                if let node = model.tree?.index(ofPath: facts.path) {
                    trash([node], recheck: recheck)
                } else {
                    trash(paths: [facts.path], bytes: facts.bytes, title: "“\(facts.name)”", recheck: recheck)
                }
            }
        case .trashContents:
            let busy = facts.busyItems
            let paths = facts.names.filter { !busy.contains($0) && $0 != ".DS_Store" && $0 != ".localized" }.sorted()
                .map { facts.path + "/" + $0 }
            trashAfterChecking(paths, in: facts.path, bytes: facts.bytes, title: "what “\(facts.name)” holds")
        case let .trashItems(paths):
            let title = paths.count == 1
                ? "“\((paths[0] as NSString).lastPathComponent)”" : "\(DiskFormat.count(paths.count, "item")) in “\(facts.name)”"
            trashAfterChecking(paths, in: facts.path, bytes: method.bytes ?? 0, title: title)
        case let .run(command):
            confirm(title: "Run “\(command.commandLine)”?", text: method.detail, button: "Run") { [weak self] in
                self?.model.runCleanup(command, in: facts.path)
            }
        case let .copyCommand(command):
            if Pasteboard.copy(command) {
                Toast.show("Copied “\(command)”", symbol: "doc.on.clipboard")
            }
        case let .openApp(bundleID, _):
            model.openApp(bundleID)
        case .showOldFiles:
            model.search = ""
            model.view = .old
            if let node = model.tree?.index(ofPath: facts.path) {
                model.focus = node
            } else {
                // Not in the open scan: scan it, and Old Files lists it.
                scan(facts.path)
            }
        case .reveal:
            SystemLinks.reveal([URL(fileURLWithPath: facts.path)])
        }
    }

    /// Moves `paths` to the Trash when no process has them open, before the confirmation and again after it.
    private func trashAfterChecking(_ paths: [String], in folder: String, bytes: Int64, title: String) {
        let recheck = inUseCheck(paths, in: folder)
        Task {
            guard await recheck() else { return }
            trash(paths: paths, bytes: bytes, title: title, recheck: recheck)
        }
    }

    /// Whether no process has any of `paths` open, saying who has when one does: Oriel never moves what an app is using.
    private func inUseCheck(_ paths: [String], in folder: String) -> @MainActor () async -> Bool {
        { [weak self] in
            guard let self else { return false }
            let users = await model.usersNow(of: folder, among: paths)
            guard users.isEmpty else {
                let names = ListFormatter.localizedString(byJoining: Set(users).sorted())
                present(.init(title: "It is in use now", text: "\(names) has files open in it. Quit it, then clean up again."))
                return false
            }
            return true
        }
    }

    /// Asks the apps to quit, as their Quit command does, and checks the folder again as each one quits.
    private func quit(_ apps: [CleanupFacts.App], thenCheck path: String) {
        stopWaitingForApps()
        let ids = Set(apps.map(\.bundleID))
        cleanupObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let id = app?.bundleIdentifier, ids.contains(id) else { return }
            MainActor.assumeIsolated {
                guard let self, let sheet = self.cleanupSheet else { return }
                self.check(path, in: sheet)
            }
        }
        for app in apps {
            for running in NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID) {
                running.terminate()
            }
        }
    }

    private func stopWaitingForApps() {
        if let cleanupObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(cleanupObserver)
        }
        cleanupObserver = nil
    }
}
