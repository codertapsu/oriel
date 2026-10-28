import CoreGraphics
import Foundation
import ImageIO
import OrielCore
import os

/// Capture history on disk (PLAN §10.4): each capture as a PNG plus a JPEG thumbnail under `AppPaths.captureHistory`,
/// and `index.json` describing them, newest first. An actor, so encoding and file IO stay off the main thread.
actor HistoryStore {
    static let thumbnailPixels = 480

    nonisolated let directory: URL
    private var cache: [HistoryEntry]?
    private let log = Log.logger("capture")

    init(directory: URL) {
        self.directory = directory
    }

    /// Every entry, newest first.
    func entries() -> [HistoryEntry] {
        loaded()
    }

    /// Writes the capture's PNG and thumbnail and puts it first in the index.
    @discardableResult
    func add(_ result: CaptureResult) throws -> HistoryEntry {
        try AppPaths.ensureDirectory(directory)
        let entry = HistoryEntry(result: result)
        guard let png = ImageEncoding.data(for: result.image, format: .png, scale: result.scale) else {
            throw CaptureError.failed("The capture could not be encoded for history.")
        }
        try png.write(to: imageURL(for: entry), options: .atomic)
        if let thumbnail = ImageEncoding.thumbnailData(for: result.image, maxPixels: Self.thumbnailPixels) {
            try thumbnail.write(to: thumbnailURL(for: entry), options: .atomic)
        }
        var all = loaded().filter { $0.id != entry.id }
        all.insert(entry, at: 0)
        try save(all)
        return entry
    }

    func remove(_ ids: Set<UUID>) throws {
        let all = loaded()
        for entry in all where ids.contains(entry.id) {
            deleteFiles(of: entry)
        }
        try save(all.filter { !ids.contains($0.id) })
    }

    func removeAll() throws {
        for entry in loaded() {
            deleteFiles(of: entry)
        }
        try save([])
    }

    /// Deletes the entries older than `days` days (0 keeps everything) and returns how many went.
    @discardableResult
    func prune(keepingDays days: Int, now: Date = Date()) throws -> Int {
        let expired = HistorySearch.expired(loaded(), keepingDays: days, now: now)
        guard !expired.isEmpty else { return 0 }
        try remove(Set(expired.map(\.id)))
        return expired.count
    }

    func setRecognizedText(_ text: String, for id: UUID) throws {
        var all = loaded()
        guard let index = all.firstIndex(where: { $0.id == id }) else { return }
        all[index].recognizedText = text
        try save(all)
    }

    /// The entries OCR has not read yet, newest first.
    func unindexed() -> [HistoryEntry] {
        loaded().filter { !$0.isIndexed }
    }

    nonisolated func imageURL(for entry: HistoryEntry) -> URL {
        directory.appending(path: entry.imageFileName)
    }

    nonisolated func thumbnailURL(for entry: HistoryEntry) -> URL {
        directory.appending(path: entry.thumbnailFileName)
    }

    nonisolated func loadImage(for entry: HistoryEntry) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(imageURL(for: entry) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private var indexURL: URL {
        directory.appending(path: "index.json")
    }

    private func loaded() -> [HistoryEntry] {
        if let cache {
            return cache
        }
        var entries: [HistoryEntry] = []
        if let data = try? Data(contentsOf: indexURL) {
            do {
                entries = try JSONDecoder().decode([HistoryEntry].self, from: data)
            } catch {
                log.error("The history index could not be read: \(error.localizedDescription, privacy: .private)")
            }
        }
        cache = entries
        return entries
    }

    private func save(_ entries: [HistoryEntry]) throws {
        try AppPaths.ensureDirectory(directory)
        try JSONEncoder().encode(entries).write(to: indexURL, options: .atomic)
        cache = entries
    }

    private func deleteFiles(of entry: HistoryEntry) {
        try? FileManager.default.removeItem(at: imageURL(for: entry))
        try? FileManager.default.removeItem(at: thumbnailURL(for: entry))
    }
}
