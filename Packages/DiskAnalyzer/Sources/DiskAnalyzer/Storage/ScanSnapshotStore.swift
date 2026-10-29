import Foundation
import OrielCore

/// The remembered scans, in `~/Library/Application Support/Oriel/DiskAnalyzer/Scans`: an index of records and one JSON
/// snapshot per scan, the newest five per folder and thirty in all. They hold folder names and sizes, never contents.
actor ScanSnapshotStore {
    static let perRoot = 5
    static let total = 30

    nonisolated let directory: URL
    private var cachedRecords: [ScanRecord]?
    private let log = Log.logger("disk")

    nonisolated static var defaultDirectory: URL {
        AppPaths.applicationSupport.appending(path: "DiskAnalyzer/Scans", directoryHint: .isDirectory)
    }

    init(directory: URL = ScanSnapshotStore.defaultDirectory) {
        self.directory = directory
    }

    func records() -> [ScanRecord] {
        if let cachedRecords {
            return cachedRecords
        }
        let records = (try? Data(contentsOf: indexURL)).flatMap { try? JSONDecoder().decode([ScanRecord].self, from: $0) } ?? []
        cachedRecords = records
        return records
    }

    /// Saves `snapshot`, prunes the oldest, and returns the records.
    @discardableResult
    func save(_ snapshot: ScanSnapshot) -> [ScanRecord] {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: snapshotURL(snapshot.id), options: .atomic)
            var records = records().filter { $0.id != snapshot.id }
            records.append(ScanRecord(snapshot))
            let dropped = ScanRecord.pruned(records, perRoot: Self.perRoot, total: Self.total)
            for id in dropped {
                try? FileManager.default.removeItem(at: snapshotURL(id))
            }
            records.removeAll { dropped.contains($0.id) }
            try write(records)
            return records
        } catch {
            log.error("A scan could not be remembered: \(error.localizedDescription, privacy: .public)")
            return records()
        }
    }

    func snapshot(_ id: UUID) -> ScanSnapshot? {
        (try? Data(contentsOf: snapshotURL(id))).flatMap { try? JSONDecoder().decode(ScanSnapshot.self, from: $0) }
    }

    /// The newest snapshot of `rootPath` other than `excluding`.
    func previous(of rootPath: String, excluding id: UUID?) -> ScanSnapshot? {
        let record = records().filter { $0.rootPath == rootPath && $0.id != id }.max { $0.date < $1.date }
        return record.flatMap { snapshot($0.id) }
    }

    /// Forgets every scan of `rootPath`.
    @discardableResult
    func remove(rootPath: String) -> [ScanRecord] {
        var records = records()
        for record in records where record.rootPath == rootPath {
            try? FileManager.default.removeItem(at: snapshotURL(record.id))
        }
        records.removeAll { $0.rootPath == rootPath }
        try? write(records)
        return records
    }

    private var indexURL: URL {
        directory.appending(path: "index.json")
    }

    private func snapshotURL(_ id: UUID) -> URL {
        directory.appending(path: id.uuidString + ".json")
    }

    private func write(_ records: [ScanRecord]) throws {
        try JSONEncoder().encode(records).write(to: indexURL, options: .atomic)
        cachedRecords = records
    }
}
