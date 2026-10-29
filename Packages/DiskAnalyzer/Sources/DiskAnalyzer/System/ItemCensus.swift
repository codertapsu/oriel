import Darwin
import Foundation

/// The files and content bytes of an item, counted without following symbolic links: a move to another volume checks
/// that the copy has the same before it removes the original.
nonisolated struct ItemCensus: Equatable, Sendable {
    var files = 0
    var bytes: Int64 = 0

    static func of(_ url: URL) -> ItemCensus {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return ItemCensus() }
        guard info.st_mode & S_IFMT == S_IFDIR else {
            return ItemCensus(files: 1, bytes: Int64(info.st_size))
        }
        var census = ItemCensus()
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys, options: []) else {
            return census
        }
        for case let item as URL in enumerator {
            guard let values = try? item.resourceValues(forKeys: Set(keys)), values.isDirectory != true else { continue }
            census.files += 1
            census.bytes += Int64(values.fileSize ?? 0)
        }
        return census
    }
}
