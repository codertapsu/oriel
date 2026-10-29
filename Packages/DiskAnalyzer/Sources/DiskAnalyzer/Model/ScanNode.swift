import Foundation

/// One file, folder or aggregate of a scan, kept compact (56 bytes, no references) so a scan of millions of files
/// stays small and a tree can be copied cheaply. Nodes refer to each other by index into `ScanTree.nodes`; children
/// form a linked list, so a folder's contents can be replaced without moving anything.
nonisolated struct ScanNode: Sendable, Equatable {
    static let none: Int32 = -1
    /// Dates are whole seconds since 2001 in 32 bits (1933–2069); this marks one that is not known.
    static let unknownDate = Int32.min

    /// Index into `ScanTree.names`.
    var name: Int32
    var parent: Int32
    var firstChild: Int32 = ScanNode.none
    var nextSibling: Int32 = ScanNode.none
    /// Bytes allocated on disk; for a folder, the total of everything below it.
    var size: Int64 = 0
    /// Bytes of content (the length of the files), which differs from `size` for sparse, compressed and cloud files.
    var logicalSize: Int64 = 0
    /// Files at or below this node: 1 for a file, the count for an aggregate of smaller files.
    var fileCount: Int32 = 0
    /// Folders below this node, not counting itself.
    var folderCount: Int32 = 0
    var created: Int32 = ScanNode.unknownDate
    var modified: Int32 = ScanNode.unknownDate
    var accessed: Int32 = ScanNode.unknownDate
    var kind: ScanNodeKind
    var category: FileCategory = .other
    var flags: ScanNodeFlags = []

    static func encode(_ date: Date?) -> Int32 {
        guard let date else { return unknownDate }
        return encode(secondsSince1970: Int64(date.timeIntervalSince1970))
    }

    static func encode(secondsSince1970 seconds: Int64) -> Int32 {
        guard seconds != 0 else { return unknownDate }
        let sinceReference = seconds - Int64(Date.timeIntervalBetween1970AndReferenceDate)
        return Int32(clamping: sinceReference == Int64(unknownDate) ? sinceReference + 1 : sinceReference)
    }

    static func decode(_ value: Int32) -> Date? {
        value == unknownDate ? nil : Date(timeIntervalSinceReferenceDate: TimeInterval(value))
    }

    var createdDate: Date? {
        Self.decode(created)
    }

    var modifiedDate: Date? {
        Self.decode(modified)
    }

    var accessedDate: Date? {
        Self.decode(accessed)
    }

    var isRemoved: Bool {
        flags.contains(.removed)
    }
}
