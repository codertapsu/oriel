import Foundation

/// One disk's cumulative activity since it appeared, from its `IOBlockStorageDriver`'s `Statistics` dictionary.
nonisolated struct DiskCounters: Sendable, Equatable, Codable {
    var bytesRead: UInt64
    var bytesWritten: UInt64
    var reads: UInt64
    var writes: UInt64

    static func + (lhs: DiskCounters, rhs: DiskCounters) -> DiskCounters {
        DiskCounters(
            bytesRead: lhs.bytesRead &+ rhs.bytesRead,
            bytesWritten: lhs.bytesWritten &+ rhs.bytesWritten,
            reads: lhs.reads &+ rhs.reads,
            writes: lhs.writes &+ rhs.writes
        )
    }

    /// Reads the dictionary's `Bytes (Read)`, `Bytes (Write)`, `Operations (Read)` and `Operations (Write)`.
    init?(statistics: [String: Any]) {
        func number(_ key: String) -> UInt64? {
            (statistics[key] as? NSNumber)?.uint64Value
        }
        guard let read = number("Bytes (Read)"), let written = number("Bytes (Write)") else { return nil }
        self.init(
            bytesRead: read,
            bytesWritten: written,
            reads: number("Operations (Read)") ?? 0,
            writes: number("Operations (Write)") ?? 0
        )
    }

    init(bytesRead: UInt64 = 0, bytesWritten: UInt64 = 0, reads: UInt64 = 0, writes: UInt64 = 0) {
        self.bytesRead = bytesRead
        self.bytesWritten = bytesWritten
        self.reads = reads
        self.writes = writes
    }

    /// What was added since `earlier`. A disk whose counters went down was ejected and attached again; it adds nothing
    /// this time.
    func added(since earlier: DiskCounters) -> DiskCounters {
        guard bytesRead >= earlier.bytesRead, bytesWritten >= earlier.bytesWritten, reads >= earlier.reads, writes >= earlier.writes
        else { return DiskCounters() }
        return DiskCounters(
            bytesRead: bytesRead - earlier.bytesRead,
            bytesWritten: bytesWritten - earlier.bytesWritten,
            reads: reads - earlier.reads,
            writes: writes - earlier.writes
        )
    }
}
