/// Files with the same content.
nonisolated struct DuplicateGroup: Sendable, Equatable, Identifiable {
    /// The content's SHA-256, in hex.
    var id: String
    /// The content size of each copy.
    var size: Int64
    var files: [Int32]
    /// What keeping one copy and removing the rest would free. Copies that are APFS clones of one another share their
    /// data, so they count once.
    var reclaimable: Int64
}
