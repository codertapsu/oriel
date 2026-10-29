/// The duplicate finder's stages, cheapest first, each run only on what the one before left: files of the same size,
/// then the same hash of their first and last bytes, then the same SHA-256 of all of it. Pure: the hashes come from a
/// closure, so the rules are tested without files.
nonisolated enum DuplicateGrouper {
    struct Candidate: Sendable, Equatable {
        var node: Int32
        /// The content size; files of different sizes cannot be the same.
        var size: Int64
        /// Bytes on disk, for what removing a copy frees.
        var allocated: Int64
        var path: String
        /// APFS's id for the file's data: clones share it, and share their blocks.
        var cloneID: UInt64?
    }

    /// Stage one: groups of two or more files of the same size, at least `minimumSize`, largest first.
    static func sizeGroups(_ candidates: [Candidate], minimumSize: Int64) -> [[Candidate]] {
        var bySize: [Int64: [Candidate]] = [:]
        for candidate in candidates where candidate.size >= minimumSize {
            bySize[candidate.size, default: []].append(candidate)
        }
        return bySize.values.filter { $0.count > 1 }.sorted { $0[0].size > $1[0].size }
    }

    /// Splits each group by `key` and keeps the parts with two or more files. A nil key (the file could not be read)
    /// leaves the file out.
    static func split<Key: Hashable>(_ groups: [[Candidate]], by key: (Candidate) -> Key?) -> [[Candidate]] {
        var result: [[Candidate]] = []
        for group in groups {
            var parts: [Key: [Candidate]] = [:]
            var order: [Key] = []
            for candidate in group {
                guard let value = key(candidate) else { continue }
                if parts[value] == nil {
                    order.append(value)
                }
                parts[value, default: []].append(candidate)
            }
            for value in order {
                if let part = parts[value], part.count > 1 {
                    result.append(part)
                }
            }
        }
        return result
    }

    /// What removing all but one copy frees: each copy's bytes on disk, once per distinct clone id beyond the first.
    static func reclaimable(_ group: [Candidate]) -> Int64 {
        guard group.count > 1 else { return 0 }
        var seenClones = Set<UInt64>()
        var distinct: [Candidate] = []
        for candidate in group {
            if let clone = candidate.cloneID {
                guard seenClones.insert(clone).inserted else { continue }
            }
            distinct.append(candidate)
        }
        // Copies can differ on disk (one compressed, one not). Counting the largest as the one kept errs on the low side.
        let sizes = distinct.map { max($0.allocated, 0) }.sorted(by: >)
        return sizes.dropFirst().reduce(0, +)
    }

    /// The final groups, from parts of identical content keyed by `hash`, largest waste first.
    static func groups(_ parts: [[Candidate]], hash: ([Candidate]) -> String) -> [DuplicateGroup] {
        parts.map { part in
            DuplicateGroup(id: hash(part), size: part[0].size, files: part.map(\.node), reclaimable: reclaimable(part))
        }
        .sorted { $0.reclaimable != $1.reclaimable ? $0.reclaimable > $1.reclaimable : $0.id < $1.id }
    }
}
