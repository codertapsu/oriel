import Synchronization

/// Folders a destination already made or found, by destination and path, so later uploads skip their `MKCOL` or
/// `mkdir`. In memory only: a folder deleted on the server meanwhile is made again after a relaunch.
final nonisolated class KnownFolders: Sendable {
    private let folders = Mutex<Set<String>>([])

    func contains(_ folder: [String], in destination: String) -> Bool {
        folders.withLock { $0.contains(Self.key(folder, destination)) }
    }

    func insert(_ folder: [String], in destination: String) {
        _ = folders.withLock { $0.insert(Self.key(folder, destination)) }
    }

    private static func key(_ folder: [String], _ destination: String) -> String {
        destination + "\u{0}" + folder.joined(separator: "/")
    }
}
