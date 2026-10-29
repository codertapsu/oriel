/// What a node of a scan stands for.
nonisolated enum ScanNodeKind: UInt8, Sendable, Codable {
    case folder
    /// A folder macOS shows as one item: an app, a library, a document bundle. Scanned inside, drawn as one.
    case package
    case file
    case symlink
    /// The files of one folder below the small-file threshold, counted together ("1,204 smaller files").
    case smallFiles
    /// A device, socket or pipe.
    case special
    /// The startup volume's sealed system and its helper volumes, which a scan does not read file by file.
    case system
    /// The part of a volume's used space that no scanned file accounts for: snapshots, unreadable folders, metadata.
    case unaccounted

    /// Whether it has, or may have, children.
    var isContainer: Bool {
        self == .folder || self == .package
    }

    /// A node made up by the scan, not a file or folder on disk.
    var isSynthetic: Bool {
        self == .smallFiles || self == .system || self == .unaccounted
    }
}
