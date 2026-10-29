/// The page counts of `host_statistics64(HOST_VM_INFO64)` that the memory breakdown needs.
nonisolated struct VMCounts: Sendable, Equatable {
    var free: UInt64 = 0
    var active: UInt64 = 0
    var inactive: UInt64 = 0
    var speculative: UInt64 = 0
    var wired: UInt64 = 0
    var purgeable: UInt64 = 0
    /// File-backed pages.
    var external: UInt64 = 0
    /// Anonymous pages.
    var `internal`: UInt64 = 0
    /// Physical pages that hold compressed memory.
    var compressor: UInt64 = 0
}
