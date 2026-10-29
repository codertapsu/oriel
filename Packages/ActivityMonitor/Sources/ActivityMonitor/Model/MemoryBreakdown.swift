/// The Mac's memory as Activity Monitor breaks it down, in bytes.
///
/// App Memory is anonymous memory that cannot be purged; Cached Files are file-backed and purgeable pages macOS can drop
/// at any time; Memory Used is App Memory, Wired and Compressed (the physical pages the compressor holds).
nonisolated struct MemoryBreakdown: Sendable, Equatable, Codable {
    let physical: UInt64
    let app: UInt64
    let wired: UInt64
    let compressed: UInt64
    let cached: UInt64
    let swapUsed: UInt64
    let swapTotal: UInt64

    init(physical: UInt64, app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64, swapUsed: UInt64, swapTotal: UInt64) {
        self.physical = physical
        self.app = app
        self.wired = wired
        self.compressed = compressed
        self.cached = cached
        self.swapUsed = swapUsed
        self.swapTotal = swapTotal
    }

    init(counts: VMCounts, pageSize: UInt64, physical: UInt64, swapUsed: UInt64, swapTotal: UInt64) {
        let appPages = counts.internal > counts.purgeable ? counts.internal - counts.purgeable : 0
        self.init(
            physical: physical,
            app: appPages * pageSize,
            wired: counts.wired * pageSize,
            compressed: counts.compressor * pageSize,
            cached: (counts.external + counts.purgeable) * pageSize,
            swapUsed: swapUsed,
            swapTotal: swapTotal
        )
    }

    var used: UInt64 {
        min(physical, app + wired + compressed)
    }

    /// What neither Memory Used nor Cached Files take.
    var free: UInt64 {
        let taken = used + cached
        return physical > taken ? physical - taken : 0
    }
}
