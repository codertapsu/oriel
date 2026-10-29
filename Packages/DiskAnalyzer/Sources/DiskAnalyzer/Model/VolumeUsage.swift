/// A volume's capacity, as macOS reports it, and what follows from it. On APFS every volume of a container reports the
/// container's capacity and free space.
///
/// macOS keeps three "available" figures. `available` is free right now. `availableForImportantUsage` adds what macOS
/// would free for something the user asked for — purgeable space: local Time Machine snapshots, iCloud files that are
/// safe in iCloud, caches marked purgeable — so purgeable ≈ important − available. `availableForOpportunisticUsage`
/// is what background work may count on, often less than `available`.
nonisolated struct VolumeUsage: Sendable, Equatable, Codable {
    var total: Int64
    var available: Int64
    var availableForImportantUsage: Int64?
    var availableForOpportunisticUsage: Int64?

    /// Everything that is not free, purgeable space included, as Finder's "used" counts it.
    var used: Int64 {
        max(0, total - max(0, available))
    }

    /// What macOS can free by itself when space is needed.
    var purgeable: Int64 {
        guard let important = availableForImportantUsage else { return 0 }
        return max(0, min(important, total) - max(0, available))
    }

    /// Space taken by things macOS will not remove by itself.
    var usedWithoutPurgeable: Int64 {
        max(0, used - purgeable)
    }

    /// What can be used for a large download or copy: the free space plus what macOS would purge for it.
    var availableIncludingPurgeable: Int64 {
        min(total, max(0, available) + purgeable)
    }

    /// The share of the capacity `bytes` is, from 0 to 1; 0 when the capacity is not known.
    func fraction(_ bytes: Int64) -> Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(bytes) / Double(total)))
    }

    /// Whether the volume is nearly full: less than 10 % or 10 GB available, purgeable space included.
    var isNearlyFull: Bool {
        total > 0 && (fraction(availableIncludingPurgeable) < 0.1 || availableIncludingPurgeable < 10_000_000_000)
    }
}
