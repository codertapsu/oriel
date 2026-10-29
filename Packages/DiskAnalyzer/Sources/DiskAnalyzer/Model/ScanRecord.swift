import Foundation

/// One remembered scan, as the sidebar's Recent Scans lists it; the full snapshot is read only to compare.
nonisolated struct ScanRecord: Codable, Sendable, Equatable, Identifiable {
    var id: UUID
    var rootPath: String
    var displayName: String
    var date: Date
    var totalBytes: Int64
    var files: Int

    init(_ snapshot: ScanSnapshot) {
        id = snapshot.id
        rootPath = snapshot.rootPath
        displayName = snapshot.displayName
        date = snapshot.date
        totalBytes = snapshot.totalBytes
        files = snapshot.files
    }

    /// The newest record of each folder, newest first, at most `limit`.
    static func latestPerRoot(_ records: [ScanRecord], limit: Int) -> [ScanRecord] {
        var seen = Set<String>()
        var result: [ScanRecord] = []
        for record in records.sorted(by: { $0.date > $1.date }) where seen.insert(record.rootPath).inserted {
            result.append(record)
            if result.count == limit {
                break
            }
        }
        return result
    }

    /// The records to drop so that each folder keeps its newest `perRoot` and all of them the newest `total`.
    static func pruned(_ records: [ScanRecord], perRoot: Int, total: Int) -> Set<UUID> {
        var kept = 0
        var perFolder: [String: Int] = [:]
        var dropped = Set<UUID>()
        for record in records.sorted(by: { $0.date > $1.date }) {
            let count = perFolder[record.rootPath, default: 0]
            if count >= perRoot || kept >= total {
                dropped.insert(record.id)
            } else {
                perFolder[record.rootPath] = count + 1
                kept += 1
            }
        }
        return dropped
    }
}
