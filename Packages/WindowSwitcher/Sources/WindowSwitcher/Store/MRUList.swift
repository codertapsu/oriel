/// Most-recently-used window order, in memory only (PLAN §7.1.1 item 5). Fed by focus changes and app
/// activations; windows it has never seen keep the window server's front-to-back order after the known ones.
nonisolated struct MRUList: Sendable, Equatable {
    private(set) var ids: [UInt32] = []

    init(_ ids: [UInt32] = []) {
        var seen = Set<UInt32>()
        self.ids = ids.filter { seen.insert($0).inserted }
    }

    /// Moves `id` to the front.
    mutating func touch(_ id: UInt32) {
        ids.removeAll { $0 == id }
        ids.insert(id, at: 0)
    }

    mutating func remove(_ id: UInt32) {
        ids.removeAll { $0 == id }
    }

    /// Forgets windows that no longer exist.
    mutating func prune(keeping alive: Set<UInt32>) {
        ids.removeAll { !alive.contains($0) }
    }

    /// Appends ids it does not know yet, in the given order, behind the known ones.
    mutating func seed(_ ordered: [UInt32]) {
        var known = Set(ids)
        for id in ordered where known.insert(id).inserted {
            ids.append(id)
        }
    }

    /// `items` with the known ones first, most recent first, then the rest in their given order.
    func sorted<Item>(_ items: [Item], by id: (Item) -> UInt32) -> [Item] {
        var rank: [UInt32: Int] = [:]
        for (index, id) in ids.enumerated() {
            rank[id] = index
        }
        return items.enumerated()
            .sorted { lhs, rhs in
                switch (rank[id(lhs.element)], rank[id(rhs.element)]) {
                case let (left?, right?): left < right
                case (.some, nil): true
                case (nil, .some): false
                case (nil, nil): lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }
}
