@testable import DiskAnalyzer
import Foundation

/// Trees, entries and folders on disk for the tests.
enum Fixtures {
    /// A finished tree from relative file paths and their sizes; folders are made as needed, and a path ending in
    /// "/" is an empty folder.
    static func tree(
        _ files: [String: Int64],
        rootPath: String = "/Root",
        modified: [String: Date] = [:],
        small: [String: (count: Int, size: Int64)] = [:]
    ) -> ScanTree {
        var tree = ScanTree(rootName: "Root", rootPath: rootPath)
        var folders: [String: Int32] = ["": ScanTree.rootIndex]
        func folder(_ path: String) -> Int32 {
            if let known = folders[path] {
                return known
            }
            let parent = folder((path as NSString).deletingLastPathComponent)
            let name = (path as NSString).lastPathComponent
            let isPackage = FileCategoryCache.knownPackages.contains((name as NSString).pathExtension.lowercased())
            let item = DirectoryDigest.Item(name: name, kind: isPackage ? .package : .folder)
            let index = tree.append(item, to: parent)
            folders[path] = index
            return index
        }
        for (path, size) in files.sorted(by: { $0.key < $1.key }) {
            if path.hasSuffix("/") {
                _ = folder(String(path.dropLast()))
                continue
            }
            let parent = folder((path as NSString).deletingLastPathComponent)
            let name = (path as NSString).lastPathComponent
            var item = DirectoryDigest.Item(name: name, kind: .file, size: size, logicalSize: size, category: FileCategory.of(name: name))
            item.modified = ScanNode.encode(modified[path])
            tree.append(item, to: parent)
        }
        for (path, aggregate) in small.sorted(by: { $0.key < $1.key }) {
            var files = DirectoryDigest.SmallFiles()
            files.count = aggregate.count
            files.size = aggregate.size
            files.logicalSize = aggregate.size
            tree.append(files, to: folder(path))
        }
        tree.computeTotals()
        tree.finishBuilding()
        return tree
    }

    static func entry(
        _ name: String,
        _ kind: DirectoryEntry.Kind = .file,
        size: Int64 = 0,
        inode: UInt64 = 0,
        links: UInt32 = 1,
        flags: UInt32 = 0
    ) -> DirectoryEntry {
        var entry = DirectoryEntry(name: name, kind: kind)
        entry.allocatedSize = size
        entry.logicalSize = size
        entry.inode = inode
        entry.linkCount = links
        entry.fileFlags = flags
        entry.device = 1
        entry.modified = 1_700_000_000
        return entry
    }

    /// What a scan keeps of a folder holding `entries`. Its files with several hard links are counted as the first
    /// listing of a scan counts them, unless `countsLinks` is false, which leaves them waiting in `links`.
    static func digest(
        _ entries: [DirectoryEntry],
        parentPath: String = "/Root",
        options: ScanOptions = ScanOptions(),
        inherited: FileCategory? = nil,
        countsLinks: Bool = true,
        canCross: @escaping (String) -> Bool = { _ in false }
    ) -> DirectoryDigest {
        var categories = FileCategoryCache()
        let digest = DirectoryDigest.make(
            entries: entries,
            parentPath: parentPath,
            inheritedCategory: inherited,
            options: options,
            categories: &categories,
            canCrossInto: canCross
        )
        return countsLinks ? counted([digest])[0] : digest
    }

    /// `digests` with their files with several hard links counted as one scan counts the listings of its folders, one
    /// after another: a file at its first link.
    static func counted(_ digests: [DirectoryDigest]) -> [DirectoryDigest] {
        var tree = ScanTree(rootName: "Root", rootPath: "/Root")
        return digests.enumerated().map { number, digest in
            var digest = digest
            let folder = tree.append(DirectoryDigest.Item(name: "Folder \(number)", kind: .folder), to: ScanTree.rootIndex)
            _ = tree.merge(&digest, into: folder)
            return digest
        }
    }

    /// The index of the node at `relative` in `tree`.
    static func index(_ relative: String, in tree: ScanTree) -> Int32? {
        tree.index(ofPath: relative.isEmpty ? tree.rootPath : tree.rootPath + "/" + relative)
    }

    /// The bytes a file takes on disk, as a scan counts them.
    static func allocated(_ url: URL) -> Int64 {
        var info = stat()
        return lstat(url.path, &info) == 0 ? Int64(info.st_blocks) * 512 : 0
    }

    /// A volume of the test's own with `used` bytes used. Nothing is mounted at its path, so its figures are these.
    static func volume(used: Int64, total: Int64 = 4_000_000_000_000) -> VolumeInfo {
        let usage = VolumeUsage(total: total, available: total - used, availableForImportantUsage: nil, availableForOpportunisticUsage: nil)
        return VolumeInfo(path: "/Volumes/Oriel Test \(UUID().uuidString)", name: "Test", format: "APFS", usage: usage, kind: .external)
    }
}

/// A folder of its own in the temporary directory, removed (permissions restored first) when the test is done.
final class TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appending(path: "OrielDiskTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    var path: String {
        url.path
    }

    @discardableResult
    func file(_ relative: String, size: Int, byte: UInt8 = 0x5A) throws -> URL {
        let file = url.appending(path: relative)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: byte, count: size).write(to: file)
        return file
    }

    @discardableResult
    func folder(_ relative: String) throws -> URL {
        let folder = url.appending(path: relative, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    func remove() {
        if let enumerator = FileManager.default.enumerator(atPath: path) {
            chmod(path, 0o755)
            while let relative = enumerator.nextObject() as? String {
                chmod(path + "/" + relative, 0o755)
            }
        }
        chmod(path, 0o755)
        try? FileManager.default.removeItem(at: url)
    }

    deinit {
        remove()
    }
}
