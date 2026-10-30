import Foundation

/// What a finished scan found, beyond the tree: the counts, what it could not read, and the file-type totals.
nonisolated struct ScanSummary: Sendable, Equatable {
    /// A folder that could not be read, at the path the user knows.
    struct UnreadableFolder: Sendable, Equatable {
        var path: String
        var reason: UnreadableReason
    }

    var files = 0
    var folders = 0
    var bytes: Int64 = 0
    var logicalBytes: Int64 = 0
    /// Folders that could not be opened: `administratorFolders` only an administrator can open, `protectedFolders` macOS
    /// protects, and the rest failed some other way.
    var unreadableFolders = 0
    var administratorFolders = 0
    var protectedFolders = 0
    /// Up to `unreadableSampleLimit` of them, to show what is missing.
    var unreadableSamples: [UnreadableFolder] = []
    var cloudOnlyFiles = 0
    /// The content size of files that are in the cloud only, which takes no space on this Mac.
    var cloudOnlyBytes: Int64 = 0
    /// Further links to files counted once.
    var duplicateLinks = 0
    var entryErrors = 0
    var categories = CategoryTotals()
    var startedAt = Date()
    var duration: Duration = .zero
    var wasCancelled = false

    static let unreadableSampleLimit = 50

    mutating func absorb(_ digest: DirectoryDigest) {
        categories.merge(digest.categoryTotals)
        cloudOnlyFiles += digest.cloudOnlyFiles
        cloudOnlyBytes += digest.cloudOnlyBytes
        duplicateLinks += digest.duplicateLinks
        entryErrors += digest.entryErrors
    }

    mutating func noteUnreadable(_ path: String, reason: UnreadableReason) {
        unreadableFolders += 1
        switch reason {
        case .needsAdministrator: administratorFolders += 1
        case .protectedByMacOS: protectedFolders += 1
        case .other: break
        }
        if unreadableSamples.count < Self.unreadableSampleLimit {
            unreadableSamples.append(UnreadableFolder(path: path, reason: reason))
        }
    }

    /// Counts the folders that could not be read again, from the tree: after some were read as an administrator.
    mutating func recountUnreadable(in tree: ScanTree) {
        unreadableFolders = 0
        administratorFolders = 0
        protectedFolders = 0
        unreadableSamples = []
        var folders = tree.descendants(of: ScanTree.rootIndex) { $0.flags.contains(.unreadable) }.sorted()
        if tree.root.flags.contains(.unreadable) {
            folders.insert(ScanTree.rootIndex, at: 0)
        }
        for folder in folders {
            noteUnreadable(tree.displayPath(of: folder), reason: UnreadableReason(flags: tree[folder].flags))
        }
    }

    /// The samples that could not be read for `reason`.
    func samples(_ reason: UnreadableReason) -> [String] {
        unreadableSamples.filter { $0.reason == reason }.map(\.path)
    }
}
