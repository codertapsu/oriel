import AppKit
import Observation
import OrielCore

/// The state and the actions of Settings → Disk Space Analyzer.
@Observable
final class DiskSettingsModel {
    @ObservationIgnored private weak var module: DiskAnalyzerModule?
    /// Oriel's helper for Read as Administrator, read when the pane appears and when Oriel comes to the front.
    private(set) var helperStatus = PrivilegedReader.Status.unavailable

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

    // MARK: Read as Administrator

    var helperExplanation: String {
        switch helperStatus {
        case .unavailable:
            "Read as Administrator, in the window, asks for an administrator's password each time: this build of Oriel has no "
                + "helper, or this account is not an administrator's."
        case .notInstalled:
            "Read as Administrator, in the window, asks for an administrator's password each time. Oriel's helper reads these "
                + "folders in every scan instead, once you allow it in System Settings, where macOS asks for the password once. It "
                + "only reads folders, and only Oriel, run by an administrator, can use it."
        case .needsApproval:
            "Oriel's helper is installed. Switch on Oriel under Allow in the Background in System Settings → General → Login "
                + "Items & Extensions; macOS asks for an administrator's password once."
        case .allowed:
            "Oriel's helper is allowed: it reads the folders only an administrator can open, and nothing else, without asking."
        }
    }

    func refreshHelperStatus() {
        Task {
            helperStatus = await Task.detached(priority: .utility) { PrivilegedReader.status }.value
        }
    }

    /// Registers the helper and opens Login Items, where the user switches it on.
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
                let alert = NSAlert()
                alert.messageText = "Oriel's helper could not be installed"
                alert.informativeText = failure
                alert.runModal()
                return
            }
            settings?[DiskSettings.helperBuild] = PrivilegedReader.build
            PrivilegedReader.openLoginItems()
            refreshHelperStatus()
        }
    }

    func openLoginItems() {
        PrivilegedReader.openLoginItems()
    }

    func removeHelper() {
        Task {
            await Task.detached(priority: .userInitiated) { PrivilegedReader.uninstall() }.value
            settings?[DiskSettings.helperBuild] = ""
            refreshHelperStatus()
        }
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
