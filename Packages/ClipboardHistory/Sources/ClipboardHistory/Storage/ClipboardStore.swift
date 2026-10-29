import CoreGraphics
import Foundation
import ImageIO
import OrielCore
import os
import SharedUI

/// Clipboard History on disk (PLAN §7.9): `index.sealed` lists the items, and each item's contents and thumbnail are
/// files of their own under `items/`, all sealed by `ClipboardVault`. Items deleted in the panel wait in `trash/` until
/// it closes, for Undo. An actor, so file IO and encryption stay off the main thread; contents are read `nonisolated`
/// for previews and drags.
actor ClipboardStore {
    nonisolated static let thumbnailPixels = 160

    nonisolated let directory: URL
    nonisolated let vault: ClipboardVault
    private var cache: ClipboardIndex?
    private let log = Log.logger("clipboard")

    init(directory: URL, vault: ClipboardVault) {
        self.directory = directory
        self.vault = vault
    }

    // MARK: Reading

    func index() -> ClipboardIndex {
        loaded()
    }

    /// Images whose text Vision has not read yet, newest first.
    func unindexedImages() -> [ClipboardItem] {
        loaded().all.filter { $0.kind == .image && $0.recognizedText == nil }
    }

    /// Bytes the history takes on disk.
    func diskUsage() -> Int {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: Array(keys)) else { return 0 }
        var total = 0
        while let url = enumerator.nextObject() as? URL {
            total += (try? url.resourceValues(forKeys: keys).totalFileAllocatedSize) ?? 0
        }
        return total
    }

    nonisolated func content(of id: UUID) -> PasteboardSnapshot? {
        guard let sealed = try? Data(contentsOf: contentURL(id)), let data = try? vault.open(sealed) else { return nil }
        return try? PropertyListDecoder().decode(PasteboardSnapshot.self, from: data)
    }

    nonisolated func thumbnail(of id: UUID) -> CGImage? {
        guard let sealed = try? Data(contentsOf: thumbnailURL(id)), let data = try? vault.open(sealed),
              let source = CGImageSourceCreateWithData(data as CFData, nil)
        else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// The image an item holds, at most `maxPixels` on its longer side; nil `maxPixels` keeps its size.
    nonisolated func image(of id: UUID, maxPixels: Int?) -> CGImage? {
        guard let content = content(of: id), let type = ClipboardImages.preferredType(among: content.types),
              let data = content.data(for: type)
        else { return nil }
        return ClipboardImages.image(from: data, type: type, maxPixels: maxPixels)
    }

    // MARK: Changes

    /// Starts a session: empties a trash a crash left behind and deletes files that no item names.
    func prepare() {
        emptyTrash()
        let names = Set(loaded().all.map(\.id.uuidString))
        let files = (try? FileManager.default.contentsOfDirectory(at: itemsDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where !names.contains(String(file.lastPathComponent.prefix(36))) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    /// Keeps a copy: a new item, or the item it repeats with a newer date and source. Returns nil when there was
    /// nothing worth keeping.
    @discardableResult
    func record(
        _ snapshot: PasteboardSnapshot,
        label: String?,
        sourceName: String?,
        sourceBundleID: String?,
        date: Date
    ) throws -> ClipboardItem? {
        let kept = ClipboardTypes.kept(snapshot)
        // Oriel's own copies are not read through PasteboardReader, so its size limit is applied here too.
        guard kept.byteCount <= PasteboardReader.maxBytes,
              let classification = ClipboardClassifier.classify(kept, label: label)
        else { return nil }
        var index = loaded()
        let copy = ClipboardItem(
            classification: classification,
            byteCount: kept.byteCount,
            sourceName: sourceName,
            sourceBundleID: sourceBundleID,
            date: date
        )
        var item = index.record(copy).item
        try writeContent(kept, for: item.id)
        if item.kind == .image, !item.hasThumbnail, let thumbnail = thumbnailData(for: kept) {
            try seal(thumbnail, to: thumbnailURL(item.id))
            index.update(item.id) { $0.hasThumbnail = true }
            item.hasThumbnail = true
        }
        try save(index)
        return item
    }

    func touch(_ id: UUID, at date: Date) throws {
        var index = loaded()
        index.touch(id, at: date)
        try save(index)
    }

    /// Deletes items for good, without Undo.
    func delete(_ ids: Set<UUID>) throws {
        var index = loaded()
        let removals = index.remove(ids)
        guard !removals.isEmpty else { return }
        try save(index)
        for removal in removals {
            deleteFiles(of: removal.item.id)
        }
    }

    /// Deletes items so that Undo can bring them back until `emptyTrash()`.
    func remove(_ ids: Set<UUID>) throws -> ClipboardDeletion {
        var index = loaded()
        let removals = index.remove(ids)
        guard !removals.isEmpty else { return ClipboardDeletion(removals: []) }
        try save(index)
        for removal in removals {
            moveFiles(of: removal.item.id, from: itemsDirectory, to: trashDirectory)
        }
        return ClipboardDeletion(removals: removals)
    }

    /// Removes the history, and the pinned items as well when asked, with Undo until `emptyTrash()`.
    func removeAll(includingPinned: Bool) throws -> ClipboardDeletion {
        let index = loaded()
        return try remove(Set((includingPinned ? index.all : index.history).map(\.id)))
    }

    /// Puts deleted items back where they were, if their files are still in the trash.
    func restore(_ deletion: ClipboardDeletion) throws {
        for removal in deletion.removals {
            moveFiles(of: removal.item.id, from: trashDirectory, to: itemsDirectory)
        }
        var index = loaded()
        index.restore(deletion.removals.filter { FileManager.default.fileExists(atPath: contentURL($0.item.id).path) })
        try save(index)
    }

    func emptyTrash() {
        try? FileManager.default.removeItem(at: trashDirectory)
    }

    func move(_ ids: [UUID], to section: ClipboardSection, at position: Int) throws {
        var index = loaded()
        index.move(ids, to: section, at: position)
        try save(index)
    }

    func setPinned(_ ids: [UUID], _ isPinned: Bool) throws {
        var index = loaded()
        index.setPinned(ids, isPinned)
        try save(index)
    }

    /// Applies the limits and returns how many items went.
    @discardableResult
    func prune(_ limits: ClipboardLimits, now: Date = Date()) throws -> Int {
        var index = loaded()
        let removed = index.prune(limits, now: now)
        guard !removed.isEmpty else { return 0 }
        try save(index)
        for item in removed {
            deleteFiles(of: item.id)
        }
        return removed.count
    }

    func setRecognizedText(_ text: String, for id: UUID) throws {
        var index = loaded()
        guard index.item(id) != nil else { return }
        index.update(id) { $0.recognizedText = text }
        try save(index)
    }

    // MARK: Files

    private var indexURL: URL {
        directory.appending(path: "index.sealed")
    }

    private var itemsDirectory: URL {
        directory.appending(path: "items", directoryHint: .isDirectory)
    }

    private var trashDirectory: URL {
        directory.appending(path: "trash", directoryHint: .isDirectory)
    }

    nonisolated func contentURL(_ id: UUID) -> URL {
        directory.appending(path: "items").appending(path: Self.contentName(id))
    }

    nonisolated func thumbnailURL(_ id: UUID) -> URL {
        directory.appending(path: "items").appending(path: Self.thumbnailName(id))
    }

    private nonisolated static func contentName(_ id: UUID) -> String {
        "\(id.uuidString).sealed"
    }

    private nonisolated static func thumbnailName(_ id: UUID) -> String {
        "\(id.uuidString).thumbnail.sealed"
    }

    private func loaded() -> ClipboardIndex {
        if let cache {
            return cache
        }
        var index = ClipboardIndex()
        if FileManager.default.fileExists(atPath: indexURL.path) {
            do {
                index = try JSONDecoder().decode(ClipboardIndex.self, from: vault.open(Data(contentsOf: indexURL)))
            } catch {
                log.error("The clipboard history could not be read; it is set aside: \(error.localizedDescription, privacy: .private)")
                setAside()
            }
        }
        cache = index
        return index
    }

    private func save(_ index: ClipboardIndex) throws {
        try prepareDirectory()
        try vault.seal(JSONEncoder().encode(index)).write(to: indexURL, options: .atomic)
        cache = index
    }

    /// Creates the folders, kept out of backups: the key never leaves this Mac, so a backup could not be read anyway.
    private func prepareDirectory() throws {
        guard !FileManager.default.fileExists(atPath: itemsDirectory.path) else { return }
        try FileManager.default.createDirectory(at: itemsDirectory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var folder = directory
        try? folder.setResourceValues(values)
    }

    /// Moves an unreadable history out of the way, where it can still be looked at, and starts afresh.
    private func setAside() {
        let aside = directory.appending(path: "unreadable", directoryHint: .isDirectory)
        try? FileManager.default.removeItem(at: aside)
        try? FileManager.default.createDirectory(at: aside, withIntermediateDirectories: true)
        for name in ["index.sealed", "items"] {
            try? FileManager.default.moveItem(at: directory.appending(path: name), to: aside.appending(path: name))
        }
    }

    private func writeContent(_ snapshot: PasteboardSnapshot, for id: UUID) throws {
        try prepareDirectory()
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        try seal(encoder.encode(snapshot), to: contentURL(id))
    }

    private func seal(_ data: Data, to url: URL) throws {
        try vault.seal(data).write(to: url, options: .atomic)
    }

    private func thumbnailData(for snapshot: PasteboardSnapshot) -> Data? {
        guard let type = ClipboardImages.preferredType(among: snapshot.types), let data = snapshot.data(for: type),
              let image = ClipboardImages.image(from: data, type: type, maxPixels: Self.thumbnailPixels)
        else { return nil }
        return ImageFile.data(for: image, format: .png)
    }

    private func deleteFiles(of id: UUID) {
        try? FileManager.default.removeItem(at: contentURL(id))
        try? FileManager.default.removeItem(at: thumbnailURL(id))
    }

    private func moveFiles(of id: UUID, from source: URL, to destination: URL) {
        try? FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for name in [Self.contentName(id), Self.thumbnailName(id)] {
            let origin = source.appending(path: name)
            guard FileManager.default.fileExists(atPath: origin.path) else { continue }
            let target = destination.appending(path: name)
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.moveItem(at: origin, to: target)
        }
    }
}
