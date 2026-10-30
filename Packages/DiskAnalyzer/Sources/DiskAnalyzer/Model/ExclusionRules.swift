import Foundation

/// The folders a scan skips (Settings → Disk Space Analyzer → Exclusions). An entry that starts with `/` or `~` is a
/// path, excluded with everything inside it; any other entry is a folder name skipped wherever it appears
/// (`node_modules`, `.git`). A skipped folder is listed, marked excluded, with no size.
nonisolated struct ExclusionRules: Sendable, Equatable {
    private(set) var paths: Set<String> = []
    private(set) var names: Set<String> = []

    init() {}

    /// Paths and names already worked out, as Read as Administrator hands them to its root process.
    init(paths: Set<String>, names: Set<String>) {
        self.paths = paths
        self.names = names
    }

    /// `firmlinks` adds the data-volume form of each path, which is what a scan of the startup volume sees.
    init(_ entries: [String], home: String, firmlinks: FirmlinkMap = .empty) {
        for entry in entries {
            let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
                let path = Self.normalize(trimmed, home: home)
                paths.insert(path)
                paths.insert(firmlinks.dataPath(for: path))
            } else {
                names.insert(trimmed)
            }
        }
    }

    var isEmpty: Bool {
        paths.isEmpty && names.isEmpty
    }

    /// Whether the folder at `path`, named `name`, is skipped.
    func excludes(path: String, name: String) -> Bool {
        names.contains(name) || paths.contains(path)
    }

    /// `~` expanded, `.`, `..` and repeated slashes resolved, and no trailing slash. Unlike `standardizingPath` it never
    /// looks at the file system, so `/private/tmp` stays `/private/tmp`.
    static func normalize(_ path: String, home: String) -> String {
        var expanded = path
        if expanded == "~" {
            expanded = home
        } else if expanded.hasPrefix("~/") {
            expanded = home + expanded.dropFirst(1)
        }
        guard expanded.hasPrefix("/") else { return expanded }
        var components: [Substring] = []
        for component in expanded.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".":
                continue
            case "..":
                _ = components.popLast()
            default:
                components.append(component)
            }
        }
        return "/" + components.joined(separator: "/")
    }
}
