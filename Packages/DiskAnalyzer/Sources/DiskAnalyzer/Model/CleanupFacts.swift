import Foundation

/// Everything Clean Up knows about one folder (PLAN §7.10 item 19): from the scan, from the folder itself (its names,
/// its tags, who may remove it) and from the processes and apps running now. `CleanupInspector` gathers them;
/// `CleanupAdvisor` decides from them alone, so every rule is tested with facts made up in the tests.
nonisolated struct CleanupFacts: Sendable, Equatable {
    /// Something inside the folder, from the scan.
    struct Child: Sendable, Equatable {
        var name: String
        var path: String
        var bytes: Int64
        var isFolder: Bool
        /// The latest use of anything in it: modified or opened.
        var lastUsed: Date?
    }

    /// A process with files open in the folder, or working in it.
    struct User: Sendable, Equatable {
        var pid: Int32
        var name: String
        /// When it is an app: its bundle ID, to offer quitting it.
        var bundleID: String?
        /// The items directly in the folder it has open something in, by name.
        var items: Set<String>
        /// Some of the paths it has open in the folder.
        var paths: [String] = []
    }

    /// An app the folder's path names, by bundle ID or by name.
    struct App: Sendable, Equatable {
        var bundleID: String
        var name: String
        var isRunning: Bool
    }

    /// As the window shows it, through the firmlinks (`/Users/…`).
    var path: String
    var home: String
    var bytes: Int64
    var fileCount: Int
    var folderCount: Int
    /// The latest use of anything in it.
    var lastUsed: Date?
    /// What it holds, largest first.
    var children: [Child]
    /// The outermost folders inside it named like caches (`Cache`, `Code Cache`, `GPUCache`…), largest first.
    var cacheFolders: [Child] = []
    /// Bytes per kind of content.
    var categories: [FileCategory: Int64] = [:]
    /// Git repositories inside it.
    var repositories = 0
    /// Every name directly inside it, small files included, and next to it.
    var names: Set<String> = []
    var siblingNames: Set<String> = []
    /// It holds a `CACHEDIR.TAG` with the specification's signature: the tool that made it says it is a cache.
    var isTaggedCache = false
    /// Its app keeps it out of Time Machine backups.
    var isExcludedFromBackup = false
    /// Whether the user may move it, and what it holds, to the Trash.
    var isRemovable = true
    /// Why Oriel refuses to remove or move it (`SafetyRules`), if it does.
    var refusal: String?
    /// Whether it refuses what it holds too (macOS's folders), not only the folder (a Library folder apps rely on).
    var refusesContents = false
    /// iCloud Drive or a cloud storage folder: removing it removes it from the cloud.
    var isInCloud = false
    var users: [User] = []
    /// The installed apps its path names.
    var apps: [App] = []
    /// Bundle IDs its path names that no installed app has: what is left of an app that was removed.
    var missingApps: [String] = []
    /// Every running app, for the apps a rule names.
    var runningApps: [App] = []
    var now = Date()

    var name: String {
        (path as NSString).lastPathComponent
    }

    /// The path with the home folder as `~`, as the catalog writes it.
    var homeRelativePath: String {
        path == home ? "~" : path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }

    /// The names of the items a process has open.
    var busyItems: Set<String> {
        users.reduce(into: Set<String>()) { $0.formUnion($1.items) }
    }

    /// Whether a process has something open in `path` or below it.
    func isBusy(_ path: String) -> Bool {
        users.contains { user in user.paths.contains { $0 == path || $0.hasPrefix(path + "/") } }
    }

    /// The share of its bytes in personal kinds of content: documents, pictures, videos, audio, archives.
    var personalShare: Double {
        guard bytes > 0 else { return 0 }
        let personal: [FileCategory] = [.document, .image, .video, .audio, .archive]
        return Double(personal.reduce(Int64(0)) { $0 + (categories[$1] ?? 0) }) / Double(bytes)
    }
}
