/// Counts a file with several hard links once: the first link seen gets the size, every other link of the same file
/// (same device and inode) is listed with none. Only files with more than one link are recorded, so it stays small.
nonisolated struct HardLinkRegistry: Sendable {
    private struct Identity: Hashable {
        let device: Int32
        let inode: UInt64
    }

    private var seen: Set<Identity> = []

    /// Whether this is the first link of the file seen; records it.
    mutating func isFirstLink(device: Int32, inode: UInt64) -> Bool {
        seen.insert(Identity(device: device, inode: inode)).inserted
    }

    var count: Int {
        seen.count
    }
}
