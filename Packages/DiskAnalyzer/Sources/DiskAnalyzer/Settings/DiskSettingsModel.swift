import AppKit
import Observation
import OrielCore

/// The state and the actions of Settings → Disk Space Analyzer.
@Observable
final class DiskSettingsModel {
    @ObservationIgnored private weak var module: DiskAnalyzerModule?

    init(module: DiskAnalyzerModule) {
        self.module = module
    }

    var settings: SettingsStore? {
        module?.currentSettings
    }

    var isActive: Bool {
        module?.isActive ?? false
    }

    func openAnalyzer() {
        module?.openWindow()
    }

    func openFullDiskAccess() {
        SystemLinks.open(SystemLinks.fullDiskAccess)
    }

    /// Asks for a folder to exclude and adds it, written with `~` for the home folder.
    func chooseExclusion() {
        guard let settings else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Exclude"
        panel.message = "Choose folders that scans skip."
        guard panel.runModal() == .OK else { return }
        let home = NSHomeDirectory()
        var entries = settings[DiskSettings.exclusions]
        for url in panel.urls {
            let path = url.path
            let entry = path == home || path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
            if !entries.contains(entry) {
                entries.append(entry)
            }
        }
        settings[DiskSettings.exclusions] = entries
    }

    func addExclusion(named name: String) {
        guard let settings else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/") else { return }
        var entries = settings[DiskSettings.exclusions]
        if !entries.contains(trimmed) {
            entries.append(trimmed)
            settings[DiskSettings.exclusions] = entries
        }
    }

    func removeExclusions(_ entries: Set<String>) {
        guard let settings else { return }
        settings[DiskSettings.exclusions] = settings[DiskSettings.exclusions].filter { !entries.contains($0) }
    }

    /// Forgets every remembered scan.
    func forgetAllScans() {
        let store = ScanSnapshotStore()
        Task {
            for record in await store.records() {
                await store.remove(rootPath: record.rootPath)
            }
        }
    }
}
