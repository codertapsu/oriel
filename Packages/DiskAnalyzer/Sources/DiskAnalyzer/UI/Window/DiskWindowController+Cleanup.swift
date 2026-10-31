import AppKit
import SharedUI

/// Clean Up (PLAN §7.10 item 19): the sheet, and carrying out what the user chose, for a folder of the scan or any other
/// (a space hog's). Whatever goes is checked again for processes using it, then goes through the usual confirmation to
/// the Trash.
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
        guard let window else { return }
        let sheet = CleanupSheetController(name: (path as NSString).lastPathComponent, path: path, icon: icon)
        let cancellation = CancellationFlag()
        cleanupSheet = sheet
        sheet.onChoose = { [weak self] method, facts in
            // Let the sheet go before a confirmation comes.
            Task { @MainActor in self?.carryOut(method, facts: facts) }
        }
        sheet.onReveal = { SystemLinks.reveal([URL(fileURLWithPath: path)]) }
        sheet.onQuit = { [weak self] apps in self?.quit(apps, thenCheck: path) }
        window.beginSheet(sheet.panel) { [weak self] _ in
            cancellation.cancel()
            guard let self, cleanupSheet === sheet else { return }
            cleanupSheet = nil
            stopWaitingForApps()
        }
        check(path, in: sheet, cancellation: cancellation)
    }

    /// The advice, then Apple Intelligence's reading for a folder Oriel does not know, which can only make it more careful.
    private func check(_ path: String, in sheet: CleanupSheetController, cancellation: CancellationFlag = CancellationFlag()) {
        Task {
            guard let result = await model.adviseCleanup(of: path, cancellation: cancellation), cleanupSheet === sheet else {
                sheet.close()
                return
            }
            let (facts, advice) = result
            let explaining = !advice.isKnown && model.explainsFolders
            sheet.show(advice, facts: facts, explaining: explaining)
            guard explaining else { return }
            let reading = await model.explainCleanup(facts)
            guard cleanupSheet === sheet else { return }
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
        let node = model.tree?.index(ofPath: facts.path)
        switch method.action {
        case .trashFolder:
            trashUnlessInUse([facts.path], in: facts.path) { [weak self] in
                guard let self else { return }
                if let node {
                    trash([node])
                } else {
                    trash(paths: [facts.path], bytes: facts.bytes, title: "“\(facts.name)”")
                }
            }
        case .trashContents:
            let busy = facts.busyItems
            let paths = facts.names.filter { !busy.contains($0) && $0 != ".DS_Store" && $0 != ".localized" }.sorted()
                .map { facts.path + "/" + $0 }
            trashUnlessInUse(paths, in: facts.path) { [weak self] in
                self?.trash(paths: paths, bytes: facts.bytes, title: "what “\(facts.name)” holds")
            }
        case let .trashItems(paths):
            trashUnlessInUse(paths, in: facts.path) { [weak self] in
                self?.trash(paths: paths, bytes: method.bytes ?? 0, title: "\(DiskFormat.count(paths.count, "item")) in “\(facts.name)”")
            }
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
            if let node {
                model.focus = node
            } else {
                // Not in the open scan: scan it, and Old Files lists it.
                scan(facts.path)
            }
        case .reveal:
            SystemLinks.reveal([URL(fileURLWithPath: facts.path)])
        }
    }

    /// Checks again that no process has the items open: Oriel never moves what an app is using.
    private func trashUnlessInUse(_ paths: [String], in folder: String, then trash: @escaping @MainActor () -> Void) {
        Task {
            let users = await model.usersNow(of: folder, among: paths)
            guard users.isEmpty else {
                let names = ListFormatter.localizedString(byJoining: Set(users).sorted())
                present(.init(title: "It is in use now", text: "\(names) has files open in it. Quit it, then clean up again."))
                return
            }
            trash()
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
