/// What reading one directory gave.
nonisolated enum DirectoryReadResult: Sendable, Equatable {
    /// Its entries. `error` is non-zero when the listing stopped part way, so some entries are missing.
    case listed([DirectoryEntry], error: Int32)
    /// It could not be opened: `EACCES` when only its owner may, `EPERM` when macOS protects it (`UnreadableReason`),
    /// `ENOENT` if it went away.
    case unreadable(Int32)
}
