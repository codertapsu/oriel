import Foundation

/// Moves an item to the Trash and says where it went. The system's in the app; a folder of the test's own in tests,
/// which must never put anything in the user's Trash.
nonisolated protocol Trashing: Sendable {
    func trash(_ url: URL) throws -> URL?
}

/// `FileManager.trashItem`: the item's own Trash on its volume, as Finder does, so Put Back works too.
nonisolated struct SystemTrash: Trashing {
    func trash(_ url: URL) throws -> URL? {
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        return result as URL?
    }
}
