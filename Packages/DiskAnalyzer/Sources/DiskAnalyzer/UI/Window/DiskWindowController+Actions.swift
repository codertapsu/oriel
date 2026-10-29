import AppKit
import UniformTypeIdentifiers

/// The actions that need a confirmation or a panel. A removal always names how many items and how much space;
/// deleting immediately asks twice; nothing runs on items the safety rules refuse.
extension DiskWindowController: DiskActions {
    func trash(_ nodes: [Int32]) {
        guard let plan = model.plan(.trash, nodes: nodes), refuseIfProtected(plan) else { return }
        guard model.settings[DiskSettings.confirmsTrash] else {
            model.run(plan)
            return
        }
        confirm(
            title: plan.count == 1 ? "Move “\(plan.names[0])” to the Trash?" : "Move \(DiskFormat.count(plan.count, "item")) to the Trash?",
            text: "\(listing(plan))They take \(DiskFormat.bytes(plan.bytes)). Undo or the Trash brings them back until you empty it.",
            button: "Move to Trash"
        ) { [weak self] in self?.model.run(plan) }
    }

    func deleteImmediately(_ nodes: [Int32]) {
        guard let plan = model.plan(.delete, nodes: nodes), refuseIfProtected(plan) else { return }
        let what = plan.count == 1 ? "“\(plan.names[0])”" : DiskFormat.count(plan.count, "item")
        confirm(
            title: "Delete \(what) immediately?",
            text: "\(listing(plan))This frees \(DiskFormat.bytes(plan.bytes)) now. The items do not go to the Trash and cannot be "
                + "brought back.",
            button: "Delete…",
            destructive: true
        ) { [weak self] in
            self?.confirm(
                title: "Are you sure you want to delete \(what)?",
                text: "This cannot be undone.",
                button: "Delete Immediately",
                destructive: true
            ) { [weak self] in self?.model.run(plan) }
        }
    }

    func copyTo(_ nodes: [Int32]) {
        chooseDestination(prompt: "Copy Here", message: "Choose where to copy \(describe(nodes)).") { [weak self] folder in
            guard let self, let plan = model.plan(.copy(to: folder), nodes: nodes) else { return }
            model.run(plan)
        }
    }

    func moveTo(_ nodes: [Int32]) {
        chooseDestination(prompt: "Move Here", message: "Choose where to move \(describe(nodes)).") { [weak self] folder in
            guard let self, let plan = model.plan(.move(to: folder), nodes: nodes), refuseIfProtected(plan) else { return }
            let what = plan.count == 1 ? "“\(plan.names[0])”" : DiskFormat.count(plan.count, "item")
            confirm(
                title: "Move \(what) to “\(folder.lastPathComponent)”?",
                text: "\(listing(plan))\(DiskFormat.bytes(plan.bytes)). To another volume, each item is copied and checked before the "
                    + "original is removed.",
                button: "Move"
            ) { [weak self] in self?.model.run(plan) }
        }
    }

    func trash(paths: [String], bytes: Int64, title: String) {
        guard let plan = model.plan(.trash, paths: paths, bytes: bytes) else { return }
        confirm(
            title: "Move \(title) to the Trash?",
            text: "\(listing(plan))\(DiskFormat.count(plan.count, "item")), \(DiskFormat.bytes(bytes)). Undo or the Trash brings "
                + "them back.",
            button: "Move to Trash"
        ) { [weak self] in self?.model.run(plan) }
    }

    func scan(_ path: String) {
        let home = NSHomeDirectory()
        let coversHome = path == "/" || home.hasPrefix(path.hasSuffix("/") ? path : path + "/") || path == home
            || path.hasPrefix(home + "/")
        guard coversHome, !model.settings[DiskSettings.explainedFolderAccess] else {
            model.scan(path: path)
            return
        }
        model.settings[DiskSettings.explainedFolderAccess] = true
        confirm(
            title: "macOS may ask about some folders",
            text: """
            The first time Oriel reads Desktop, Documents, Downloads, iCloud Drive or another app's files, macOS asks whether \
            it may. Choose Allow to count them. Folders you keep private are counted as folders that could not be read, \
            and Full Disk Access lets Oriel see everything.
            """,
            button: "Scan"
        ) { [weak self] in self?.model.scan(path: path) }
    }

    func chooseFolder() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true
        panel.prompt = "Scan"
        panel.message = "Choose a folder or volume to scan."
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.scan(url.path)
        }
    }

    func eject(_ volume: VolumeInfo) {
        confirm(
            title: "Eject “\(volume.name)”?",
            text: "Apps using files on it may lose unsaved changes. macOS says if something keeps it busy.",
            button: "Eject"
        ) { [weak self] in self?.model.eject(volume) }
    }

    func thinSnapshots(of volume: VolumeInfo) {
        confirm(
            title: "Remove local snapshots on “\(volume.name)”?",
            text: """
            macOS keeps local Time Machine snapshots while there is room and removes them by itself when space is needed. \
            Removing them now frees that space at once; your backups on the backup disk stay. macOS may ask for an \
            administrator's password.
            """,
            button: "Remove Snapshots"
        ) { [weak self] in self?.model.thinLocalSnapshots(of: volume) }
    }

    func deleteUnavailableSimulators() {
        confirm(
            title: "Delete unavailable simulators?",
            text: "This removes the simulators whose runtime is no longer installed, with their apps and data. Xcode never "
                + "shows them anyway.",
            button: "Delete",
            destructive: true
        ) { [weak self] in self?.model.deleteUnavailableSimulators() }
    }

    func showChanges() {
        guard let window, let diff = model.diff else { return }
        let sheet = ChangesSheetController(diff: diff, rootName: model.target?.displayName ?? "")
        changesSheet = sheet
        window.beginSheet(sheet.panel) { [weak self] _ in self?.changesSheet = nil }
    }

    func exportCSV() {
        guard let window, let tree = model.tree else { return }
        let nodes = main.exportableNodes()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(model.displayName(of: model.focus)) \(Date().formatted(.iso8601.year().month().day())).csv"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task {
                let text = await Task.detached(priority: .userInitiated) { CSVExporter.csv(nodes, in: tree) }.value
                do {
                    try Data(text.utf8).write(to: url, options: .atomic)
                } catch {
                    self?.present(.init(title: "The list was not exported", text: error.localizedDescription))
                }
            }
        }
    }

    // MARK: Helpers

    /// Shows why items cannot be removed, when none of them may be; returns whether to go on.
    private func refuseIfProtected(_ plan: DiskAnalyzerModel.Plan) -> Bool {
        let reasons = plan.nodes.compactMap { node in model.refusal(for: node).map { (model.displayName(of: node), $0) } }
        guard !reasons.isEmpty else { return true }
        let lines = reasons.prefix(5).map { "“\($0.0)”: \($0.1)" }.joined(separator: "\n")
        if reasons.count == plan.count {
            present(.init(title: reasons.count == 1 ? "Oriel won't do that" : "Oriel won't touch these items", text: lines))
            return false
        }
        // Some may go: the operator skips the others and says so afterwards.
        return true
    }

    /// The first few names, one per line, before the explanation.
    private func listing(_ plan: DiskAnalyzerModel.Plan) -> String {
        guard plan.count > 1 else { return "" }
        let shown = plan.names.prefix(5).map { "• " + $0 }.joined(separator: "\n")
        let more = plan.count > 5 ? "\n• and \(DiskFormat.count(plan.count - 5, "more item"))" : ""
        return shown + more + "\n\n"
    }

    private func describe(_ nodes: [Int32]) -> String {
        nodes.count == 1 ? "“\(model.displayName(of: nodes[0]))”" : DiskFormat.count(nodes.count, "item")
    }

    func confirm(title: String, text: String, button: String, destructive: Bool = false, then action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = destructive ? .critical : .warning
        let confirmButton = alert.addButton(withTitle: button)
        confirmButton.hasDestructiveAction = destructive
        alert.addButton(withTitle: "Cancel")
        guard let window, window.isVisible else {
            if alert.runModal() == .alertFirstButtonReturn {
                action()
            }
            return
        }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            // Let this sheet go before the next one comes.
            Task { @MainActor in action() }
        }
    }

    private func chooseDestination(prompt: String, message: String, then action: @escaping (URL) -> Void) {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.message = message
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in action(url) }
        }
    }
}
