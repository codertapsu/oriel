import AppKit
import OrielCore

/// The drives and folders the user let Oriel read, kept as security-scoped bookmarks: the App Store edition's sandbox
/// lets Oriel scan only what the user granted (PLAN §19). A grant covers everything inside it, so each place is asked
/// about once; access, once started, lasts as long as Oriel runs.
@MainActor
struct FolderGrants {
    static let key = SettingKey<[String: Data]>("diskAnalyzer.folderGrants", default: [:])

    let settings: SettingsStore

    /// Whether a grant covers `path`, starting access to it.
    func covers(_ path: String) -> Bool {
        let grants = settings[Self.key]
        let covering = grants.keys.filter { path == $0 || path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
        return covering.contains { grants[$0].flatMap(FolderBookmark.resolve) != nil }
    }

    /// Asks for `path` in an open panel there, unless a grant covers it already; `then` gets the path to scan: the one
    /// asked for, or another the user chose instead.
    func request(_ path: String, from window: NSWindow?, then scan: @escaping @MainActor (String) -> Void) {
        guard !covers(path) else {
            scan(path)
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.treatsFilePackagesAsDirectories = true
        panel.directoryURL = URL(filePath: path, directoryHint: .isDirectory)
        panel.prompt = "Allow"
        panel.message = "To scan “\((path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent)”, "
            + "let Oriel read it: choose Allow. Oriel asks once for each place."
        let finish = { (response: NSApplication.ModalResponse) in
            guard response == .OK, let url = panel.url else { return }
            if let bookmark = FolderBookmark.make(for: url) {
                settings[Self.key][url.path] = bookmark
                _ = FolderBookmark.resolve(bookmark)
            }
            scan(url.path)
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }
}
