import Foundation

/// Which files a list shows: by category, size, dates and name.
nonisolated struct FileFilter: Sendable, Equatable {
    /// Empty shows every category.
    var categories: Set<FileCategory> = []
    var minimumSize: Int64 = 0
    var modifiedBefore: Date?
    var createdBefore: Date?
    /// Files last used — opened (from Spotlight, when known), accessed or modified, whichever is latest — before this.
    var lastUsedBefore: Date?
    var nameQuery = ""
    /// Whether files that are only in the cloud are listed.
    var includesCloudOnly = true

    var isEmpty: Bool {
        self == FileFilter()
    }

    /// `lastOpened` is Spotlight's "last opened" date, for the files it was looked up for.
    func accepts(_ node: ScanNode, name: String, lastOpened: Date? = nil) -> Bool {
        if !categories.isEmpty, !categories.contains(node.category) {
            return false
        }
        if node.size < minimumSize, !(node.flags.contains(.cloudOnly) && node.logicalSize >= minimumSize) {
            return false
        }
        if !includesCloudOnly, node.flags.contains(.cloudOnly) {
            return false
        }
        if let modifiedBefore, (node.modifiedDate ?? .distantFuture) >= modifiedBefore {
            return false
        }
        if let createdBefore, (node.createdDate ?? .distantFuture) >= createdBefore {
            return false
        }
        if let lastUsedBefore, Self.lastUsed(node, lastOpened: lastOpened) >= lastUsedBefore {
            return false
        }
        if !nameQuery.isEmpty, !TextMatch.matches(name, words: TextMatch.words(of: nameQuery)) {
            return false
        }
        return true
    }

    /// When a file was last used: the latest of its modification, its access and Spotlight's "last opened". APFS
    /// updates access times lazily, so "last opened" is the better signal when Spotlight has it. An unknown date counts
    /// as recent, so a file is called old only on evidence.
    static func lastUsed(_ node: ScanNode, lastOpened: Date?) -> Date {
        let dates = [node.modifiedDate, node.accessedDate, lastOpened].compactMap(\.self)
        guard let latest = dates.max() else { return .distantFuture }
        return latest
    }
}
