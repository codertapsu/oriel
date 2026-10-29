import CoreGraphics

/// The records of the windows Window Tiling arranged, by window, most recent last. It keeps at most `capacity`, so the
/// windows of a long day never pile up: the least recently arranged is dropped first. Pure; the AX actor keeps one,
/// keyed by window element.
nonisolated struct TileHistory<Key: Hashable> {
    static var defaultCapacity: Int {
        64
    }

    let capacity: Int
    private var records: [Key: TileRecord] = [:]
    /// Least recently arranged first.
    private var order: [Key] = []

    init(capacity: Int = Self.defaultCapacity) {
        self.capacity = max(1, capacity)
    }

    var count: Int {
        records.count
    }

    /// The window's record while it is where Window Tiling left it; nil once the user has moved or resized it, which
    /// starts a new run: cycling begins at ½ again and Restore goes back to the frame the user chose.
    func record(for key: Key, at frame: CGRect) -> TileRecord? {
        guard let record = records[key], record.isCurrent(at: frame) else { return nil }
        return record
    }

    /// The frame Restore puts the window back to, even if the user moved it after Window Tiling did.
    func restoreFrame(for key: Key) -> CGRect? {
        records[key]?.restoreFrame
    }

    /// Notes that the window, which was at `frame`, was arranged by `action`. `previous` is its current record
    /// (`record(for:at:)`): while there is one, the run goes on and keeps its restore frame.
    mutating func noteArranged(
        _ key: Key,
        from frame: CGRect,
        previous: TileRecord?,
        action: TilingAction,
        step: Int,
        target: CGRect,
        result: CGRect
    ) {
        let record = TileRecord(
            restoreFrame: previous?.restoreFrame ?? frame,
            action: action,
            step: step,
            target: target,
            result: result
        )
        records[key] = record
        order.removeAll { $0 == key }
        order.append(key)
        while order.count > capacity {
            records[order.removeFirst()] = nil
        }
    }

    /// Forgets the window, after Restore or when it is gone.
    mutating func forget(_ key: Key) {
        records[key] = nil
        order.removeAll { $0 == key }
    }

    mutating func removeAll() {
        records.removeAll()
        order.removeAll()
    }
}

extension TileHistory: Sendable where Key: Sendable {}
