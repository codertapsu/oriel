import Darwin
import Foundation

/// The fallback for file systems that do not support bulk reads: `FileManager` lists the directory with the resource
/// values the scan needs prefetched in the same pass. Hard-linked files get one `lstat` each, for their device and
/// inode, which URL resource values do not give.
nonisolated enum FoundationDirectoryReader {
    static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey, .isVolumeKey, .isHiddenKey, .linkCountKey,
        .totalFileAllocatedSizeKey, .totalFileSizeKey, .creationDateKey, .contentModificationDateKey, .contentAccessDateKey,
    ]

    static func read(_ path: String) -> DirectoryReadResult {
        // The URLs and the values they cache are autoreleased: without a pool per directory, a scanning thread would
        // keep every one it made until it ends, hundreds of megabytes on a large volume.
        autoreleasepool { entries(of: path) }
    }

    private static func entries(of path: String) -> DirectoryReadResult {
        let url = URL(fileURLWithPath: path, isDirectory: true)
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: [])
        } catch {
            let code = ((error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError)?.code
            return .unreadable(code.map(Int32.init) ?? EACCES)
        }
        var entries: [DirectoryEntry] = []
        entries.reserveCapacity(contents.count)
        for item in contents {
            guard let values = try? item.resourceValues(forKeys: Set(keys)) else {
                entries.append(DirectoryEntry(name: item.lastPathComponent, kind: .special, error: EIO))
                continue
            }
            entries.append(entry(item, values))
        }
        return .listed(entries, error: 0)
    }

    private static func entry(_ item: URL, _ values: URLResourceValues) -> DirectoryEntry {
        let kind: DirectoryEntry.Kind = if values.isSymbolicLink == true {
            .symlink
        } else if values.isDirectory == true {
            .directory
        } else if values.isRegularFile == true {
            .file
        } else {
            .special
        }
        var entry = DirectoryEntry(name: item.lastPathComponent, kind: kind)
        entry.linkCount = UInt32(clamping: values.linkCount ?? 1)
        entry.allocatedSize = Int64(values.totalFileAllocatedSize ?? 0)
        entry.logicalSize = Int64(values.totalFileSize ?? 0)
        entry.created = Int64(values.creationDate?.timeIntervalSince1970 ?? 0)
        entry.modified = Int64(values.contentModificationDate?.timeIntervalSince1970 ?? 0)
        entry.accessed = Int64(values.contentAccessDate?.timeIntervalSince1970 ?? 0)
        if values.isHidden == true {
            entry.fileFlags |= DirectoryEntry.hiddenFlag
        }
        entry.isMountPoint = kind == .directory && values.isVolume == true
        if kind == .file, entry.linkCount > 1 {
            var info = stat()
            if lstat(item.path, &info) == 0 {
                entry.device = info.st_dev
                entry.inode = info.st_ino
            }
        }
        return entry
    }
}
