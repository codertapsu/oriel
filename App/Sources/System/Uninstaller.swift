import AppKit
import DiskAnalyzer
import OrielCore

/// Settings → Advanced → "Uninstall Oriel…" (PLAN §15.8): removes Application Support data, the Keychain
/// items, the login item, Disk Space Analyzer's helper, the CLI links and the preferences, then quits. The cask's
/// `zap` does the same.
@MainActor
enum Uninstaller {
    static func run(settings _: SettingsStore, keychain: KeychainStore, keychainServices: [String]) {
        let alert = NSAlert()
        alert.messageText = "Uninstall Oriel?"
        alert.informativeText = """
        This removes Oriel's settings, history, recordings folder, saved API keys and upload credentials, the login \
        item, Disk Space Analyzer's helper and the command-line tool, then quits. Screenshots you saved elsewhere are kept.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        let trash = NSButton(checkboxWithTitle: "Also move Oriel.app to the Trash", target: nil, action: nil)
        alert.accessoryView = trash
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        try? LaunchAtLogin.set(false)
        PrivilegedReader.uninstall()
        for location in CLIInstaller.installedLocations {
            try? CLIInstaller.uninstall(location)
        }
        for service in keychainServices {
            try? keychain.remove(service: service)
        }
        try? FileManager.default.removeItem(at: AppPaths.applicationSupport)
        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        if trash.state == .on {
            try? FileManager.default.trashItem(at: Bundle.main.bundleURL, resultingItemURL: nil)
        }
        NSApp.terminate(nil)
    }
}
