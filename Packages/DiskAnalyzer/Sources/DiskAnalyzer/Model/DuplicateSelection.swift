import Foundation

/// "Select All but One": in each group of duplicates, every copy but the one kept.
nonisolated enum DuplicateSelection {
    enum Keep: String, Sendable, CaseIterable {
        case newest, oldest
    }

    /// The copies to select. The kept copy is the newest or oldest by modification date; a tie keeps the one with the
    /// shortest path (usually the original), then the first.
    static func allButOne(
        _ groups: [DuplicateGroup],
        keep: Keep,
        modified: (Int32) -> Date?,
        path: (Int32) -> String
    ) -> Set<Int32> {
        var selected = Set<Int32>()
        for group in groups where group.files.count > 1 {
            let kept = group.files.min { lhs, rhs in
                let left = modified(lhs) ?? .distantPast
                let right = modified(rhs) ?? .distantPast
                if left != right {
                    return keep == .newest ? left > right : left < right
                }
                let leftPath = path(lhs)
                let rightPath = path(rhs)
                return leftPath.count != rightPath.count ? leftPath.count < rightPath.count : leftPath < rightPath
            }
            for file in group.files where file != kept {
                selected.insert(file)
            }
        }
        return selected
    }
}
