import CoreGraphics

/// Decoded thumbnails, least recently used out first, capped by bytes (PLAN §7.1.7: 48 MB). Owned by
/// `ThumbnailService`, which serializes access.
nonisolated struct ThumbnailCache {
    struct Entry {
        var image: CGImage
        var session: Int
        var lastUse: UInt64
        var cost: Int
    }

    let limit: Int
    private(set) var totalCost = 0
    private var entries: [UInt32: Entry] = [:]
    private var clock: UInt64 = 0

    init(limit: Int) {
        self.limit = limit
    }

    var count: Int {
        entries.count
    }

    var windowIDs: Set<UInt32> {
        Set(entries.keys)
    }

    /// Decoded size: rows times bytes per row.
    static func cost(of image: CGImage) -> Int {
        image.bytesPerRow * image.height
    }

    /// The entry, marked as just used.
    mutating func entry(for windowID: UInt32) -> Entry? {
        guard var entry = entries[windowID] else { return nil }
        clock += 1
        entry.lastUse = clock
        entries[windowID] = entry
        return entry
    }

    mutating func insert(_ image: CGImage, for windowID: UInt32, session: Int) {
        remove(windowID)
        let cost = Self.cost(of: image)
        guard cost <= limit else { return }
        clock += 1
        entries[windowID] = Entry(image: image, session: session, lastUse: clock, cost: cost)
        totalCost += cost
        evict(protecting: windowID)
    }

    mutating func remove(_ windowID: UInt32) {
        if let old = entries.removeValue(forKey: windowID) {
            totalCost -= old.cost
        }
    }

    /// Memory pressure: keep only `windowIDs` (the visible tiles; none when the panel is closed).
    mutating func purge(keeping windowIDs: Set<UInt32>) {
        for id in entries.keys where !windowIDs.contains(id) {
            remove(id)
        }
    }

    private mutating func evict(protecting protected: UInt32) {
        while totalCost > limit {
            guard let victim = entries.filter({ $0.key != protected }).min(by: { $0.value.lastUse < $1.value.lastUse })?.key else { return }
            remove(victim)
        }
    }
}
