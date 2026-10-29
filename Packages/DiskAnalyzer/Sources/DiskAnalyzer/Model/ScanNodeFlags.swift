/// Facts about a node that change how it is counted, shown or handled.
nonisolated struct ScanNodeFlags: OptionSet, Sendable, Hashable {
    let rawValue: UInt16

    /// A dot file or one with the hidden flag.
    static let hidden = ScanNodeFlags(rawValue: 1 << 0)
    /// A folder the scan could not open (no permission, often for want of Full Disk Access).
    static let unreadable = ScanNodeFlags(rawValue: 1 << 1)
    /// A folder whose listing stopped part way, so some of its contents are missing.
    static let partial = ScanNodeFlags(rawValue: 1 << 2)
    /// Another volume is mounted here; it is not counted unless the scan crosses volumes.
    static let mountPoint = ScanNodeFlags(rawValue: 1 << 3)
    /// A firmlink of the startup volume: its contents are counted where it points, on the data volume.
    static let firmlink = ScanNodeFlags(rawValue: 1 << 4)
    /// Skipped because of an exclusion in Settings.
    static let excluded = ScanNodeFlags(rawValue: 1 << 5)
    /// In the cloud only: its data is not on this Mac (a dataless file or folder).
    static let cloudOnly = ScanNodeFlags(rawValue: 1 << 6)
    /// APFS says it may share blocks with another file (a clone), so deleting it can free less than its size.
    static let sharesBlocks = ScanNodeFlags(rawValue: 1 << 7)
    /// A file with more than one hard link.
    static let hardLink = ScanNodeFlags(rawValue: 1 << 8)
    /// A further link to a file counted elsewhere, so its size is not counted again.
    static let duplicateLink = ScanNodeFlags(rawValue: 1 << 9)
    /// macOS may delete it by itself to free space (a purgeable file).
    static let purgeable = ScanNodeFlags(rawValue: 1 << 10)
    /// Taken out of the tree, by a file operation or because it disappeared.
    static let removed = ScanNodeFlags(rawValue: 1 << 11)
}
