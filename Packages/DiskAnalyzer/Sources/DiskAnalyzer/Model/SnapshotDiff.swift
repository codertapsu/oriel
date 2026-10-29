import Foundation

/// What changed between two scans of the same folder: the folders that grew or shrank the most. A change that one
/// subfolder explains almost entirely is shown once, at the subfolder, so the list points at the cause rather than at
/// every folder above it.
nonisolated struct SnapshotDiff: Sendable, Equatable {
    struct Change: Sendable, Equatable {
        /// Relative to the scanned folder; `""` is the folder itself.
        var path: String
        /// Nil when the folder was not followed in that scan: new, or too small then.
        var before: Int64?
        /// Nil when it is gone, or too small now.
        var after: Int64?

        var delta: Int64 {
            (after ?? 0) - (before ?? 0)
        }
    }

    var since: Date
    var totalBefore: Int64
    var totalAfter: Int64
    /// Largest growth first, then the largest shrinking.
    var changes: [Change]

    var totalDelta: Int64 {
        totalAfter - totalBefore
    }

    /// - Parameters:
    ///   - minimumChange: smaller changes are left out.
    ///   - explained: a change is dropped when one of its subfolders accounts for at least this share of it.
    static func between(
        _ old: ScanSnapshot,
        _ new: ScanSnapshot,
        minimumChange: Int64 = 50_000_000,
        explained: Double = 0.9,
        limit: Int = 200
    ) -> SnapshotDiff {
        let paths = Set(old.folderSizes.keys).union(new.folderSizes.keys).subtracting([""])
        var changes = paths.compactMap { path -> Change? in
            let change = Change(path: path, before: old.folderSizes[path], after: new.folderSizes[path])
            return abs(change.delta) >= minimumChange ? change : nil
        }
        let byPath = Dictionary(uniqueKeysWithValues: changes.map { ($0.path, $0.delta) })
        changes.removeAll { change in
            byPath.contains { other in
                other.key.hasPrefix(change.path + "/") && (other.value > 0) == (change.delta > 0)
                    && Double(abs(other.value)) >= explained * Double(abs(change.delta))
            }
        }
        changes.sort { lhs, rhs in
            if (lhs.delta > 0) != (rhs.delta > 0) {
                return lhs.delta > 0
            }
            return abs(lhs.delta) != abs(rhs.delta) ? abs(lhs.delta) > abs(rhs.delta) : lhs.path < rhs.path
        }
        return SnapshotDiff(
            since: old.date,
            totalBefore: old.totalBytes,
            totalAfter: new.totalBytes,
            changes: Array(changes.prefix(limit))
        )
    }
}
