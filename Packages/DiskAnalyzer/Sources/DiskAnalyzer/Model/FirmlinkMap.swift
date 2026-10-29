import Foundation

/// The startup volume's firmlinks (`/usr/share/firmlinks`): `/Users` on the sealed system volume is really
/// `/System/Volumes/Data/Users`. A scan of the startup volume reads the data volume, where everything writable lives,
/// and shows each path the way the rest of macOS does.
nonisolated struct FirmlinkMap: Sendable, Equatable {
    /// Where the data volume is mounted.
    static let dataVolume = "/System/Volumes/Data"

    /// User-facing path (`/Users`) → path on the data volume (`/System/Volumes/Data/Users`), longest first.
    let links: [(visible: String, data: String)]

    static func == (lhs: FirmlinkMap, rhs: FirmlinkMap) -> Bool {
        lhs.links.map(\.visible) == rhs.links.map(\.visible) && lhs.links.map(\.data) == rhs.links.map(\.data)
    }

    init(links: [(visible: String, data: String)]) {
        self.links = links.sorted { $0.data.count > $1.data.count }
    }

    /// Parses `/usr/share/firmlinks`: one firmlink per line, its path, a tab, then its target relative to the data
    /// volume.
    init(parsing text: String, dataVolume: String = FirmlinkMap.dataVolume) {
        let links = text.split(whereSeparator: \.isNewline).compactMap { line -> (String, String)? in
            let parts = line.split(separator: "\t", omittingEmptySubsequences: true)
            guard parts.count == 2, parts[0].hasPrefix("/") else { return nil }
            let target = parts[1].trimmingCharacters(in: .whitespaces)
            guard !target.isEmpty, !target.hasPrefix("/") else { return nil }
            return (String(parts[0]), dataVolume + "/" + target)
        }
        self.init(links: links)
    }

    static let empty = FirmlinkMap(links: [])

    /// The path the user knows for a path on the data volume: `/System/Volumes/Data/Users/me` → `/Users/me`. Paths
    /// outside the firmlinks are returned as they are.
    func visiblePath(for path: String) -> String {
        for link in links where path == link.data || path.hasPrefix(link.data + "/") {
            return link.visible + path.dropFirst(link.data.count)
        }
        return path
    }

    /// The data volume's path for a user-facing one: `/Users/me` → `/System/Volumes/Data/Users/me`.
    func dataPath(for path: String) -> String {
        let byVisible = links.sorted { $0.visible.count > $1.visible.count }
        guard let link = byVisible.first(where: { path == $0.visible || path.hasPrefix($0.visible + "/") }) else { return path }
        return link.data + path.dropFirst(link.visible.count)
    }
}
