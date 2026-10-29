import Foundation

/// A folder on this Mac or a mounted share: the file is copied a megabyte at a time (so the progress bar moves and
/// Cancel works on a slow share) into a hidden partial file, which is renamed once complete, so a web server serving
/// the folder never hands out half a file. A name already there gets a number ("Shot 2.png").
nonisolated struct SharedFolderDestination: DestinationUploader {
    let configuration: SharedFolderConfiguration

    static let chunkSize = 1 << 20

    func upload(_ payload: UploadPayload, to path: [String], progress: @escaping UploadProgressHandler) async throws -> UploadReceipt {
        let (folder, updated) = SharedFolderAccess.resolve(configuration)
        try SharedFolderAccess.check(folder, displayPath: displayPath(folder))
        let manager = FileManager.default
        let directory = path.dropLast().reduce(folder) { $0.appending(path: $1, directoryHint: .isDirectory) }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let finalPath = (1 ... 9999).lazy.map({ UploadRename.numbered(path, $0) }).first(where: {
            !manager.fileExists(atPath: Self.file(folder, $0).path)
        }) else {
            throw UploadError.failed("The folder already has too many files with this name.")
        }
        let target = Self.file(folder, finalPath)
        let partial = target.deletingLastPathComponent().appending(path: ".\(target.lastPathComponent).oriel-partial")
        do {
            try await Self.copy(payload.fileURL, to: partial, total: payload.byteCount, progress: progress)
            try manager.moveItem(at: partial, to: target)
        } catch {
            try? manager.removeItem(at: partial)
            throw UploadError.from(error)
        }
        let link = UploadLinkTemplate.link(configuration.publicURLTemplate, path: finalPath)
            ?? SharedFolderAccess.networkLink(for: target)
            ?? target
        return UploadReceipt(link: link, path: finalPath, updatedTarget: updated.map(UploadTarget.sharedFolder))
    }

    /// Writes and removes a small file, which shows the folder is there and writable.
    func testConnection() async throws -> String {
        let (folder, _) = SharedFolderAccess.resolve(configuration)
        let shown = displayPath(folder)
        try SharedFolderAccess.check(folder, displayPath: shown)
        let probe = folder.appending(path: ".oriel-write-test-\(UUID().uuidString)")
        do {
            try Data("Oriel connection test".utf8).write(to: probe)
            try FileManager.default.removeItem(at: probe)
        } catch {
            try? FileManager.default.removeItem(at: probe)
            throw UploadError.forbidden("Oriel can't write into \(shown): \(error.localizedDescription)")
        }
        return "Oriel can write into \(shown)."
    }

    private func displayPath(_ folder: URL) -> String {
        "“\((folder.path as NSString).abbreviatingWithTildeInPath)”"
    }

    private static func file(_ folder: URL, _ path: [String]) -> URL {
        path.reduce(folder) { $0.appending(path: $1) }
    }

    /// Copies a chunk at a time, yielding between chunks so the copy can be cancelled.
    static func copy(_ source: URL, to destination: URL, total: Int64, progress: UploadProgressHandler) async throws {
        let manager = FileManager.default
        guard manager.createFile(atPath: destination.path, contents: nil) else {
            throw UploadError.forbidden("Oriel can't write into “\(destination.deletingLastPathComponent().lastPathComponent)”.")
        }
        let input = try FileHandle(forReadingFrom: source)
        defer { try? input.close() }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        var copied: Int64 = 0
        var reported = ContinuousClock.now
        progress(.sending(0, of: total))
        while let chunk = try input.read(upToCount: chunkSize), !chunk.isEmpty {
            try Task.checkCancellation()
            try output.write(contentsOf: chunk)
            copied += Int64(chunk.count)
            if ContinuousClock.now - reported >= .milliseconds(100) {
                reported = .now
                progress(.sending(copied, of: total))
            }
            await Task.yield()
        }
        try output.synchronize()
        progress(.sending(copied, of: max(total, copied)))
    }
}
