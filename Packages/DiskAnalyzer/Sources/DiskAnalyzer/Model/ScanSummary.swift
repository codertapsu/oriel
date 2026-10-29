import Foundation

/// What a finished scan found, beyond the tree: the counts, what it could not read, and the file-type totals.
nonisolated struct ScanSummary: Sendable, Equatable {
    var files = 0
    var folders = 0
    var bytes: Int64 = 0
    var logicalBytes: Int64 = 0
    /// Folders that could not be opened, mostly for want of Full Disk Access.
    var unreadableFolders = 0
    /// Up to `unreadableSampleLimit` of their paths, as the user knows them, to show what is missing.
    var unreadableSamples: [String] = []
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

    mutating func noteUnreadable(_ path: String) {
        unreadableFolders += 1
        if unreadableSamples.count < Self.unreadableSampleLimit {
            unreadableSamples.append(path)
        }
    }
}
