import CoreServices
import Foundation

/// Spotlight's "last opened" date (`kMDItemLastUsedDate`) of single files, looked up one by one for the candidates
/// Old Files is about to show: no query over the disk. It is often better than the access date, which APFS updates
/// lazily; a file Spotlight does not index has none.
nonisolated enum LastOpenedDates {
    /// The attribute's name, which is also its constant's value.
    private static let attribute = "kMDItemLastUsedDate"

    static func date(of path: String) -> Date? {
        guard let item = MDItemCreate(kCFAllocatorDefault, path as CFString) else { return nil }
        return MDItemCopyAttribute(item, attribute as CFString) as? Date
    }

    /// The dates of `paths` (node → path), at most `limit` of them, stopping when cancelled.
    static func dates(of paths: [(node: Int32, path: String)], limit: Int = 600, cancellation: CancellationFlag) -> [Int32: Date] {
        var dates: [Int32: Date] = [:]
        for (node, path) in paths.prefix(limit) {
            guard !cancellation.isCancelled else { break }
            if let date = date(of: path) {
                dates[node] = date
            }
        }
        return dates
    }
}
