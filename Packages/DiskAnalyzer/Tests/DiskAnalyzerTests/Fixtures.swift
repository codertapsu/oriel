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

    /// A file only in the cloud (dataless): no blocks on this Mac, `content` bytes of content. No test can make one on
    /// disk without a cloud provider.
    static func cloudFile(_ name: String, content: Int64, inode: UInt64 = 0, links: UInt32 = 1) -> DirectoryEntry {
        var entry = entry(name, inode: inode, links: links, flags: DirectoryEntry.datalessFlag)
        entry.logicalSize = content
        return entry
    }

    /// An entry the file system reported an error for, which a listing leaves out and counts.
    static func failedEntry(_ name: String) -> DirectoryEntry {
        var entry = entry(name)
        entry.error = EIO
        return entry
    }

    /// A scan of folders held in memory, as `ScanEngine` scans folders on disk: `listings` gives each folder's entries by
    /// its path below the root ("" for the root), each listing goes into the tree as the engine adds it, and the summary
    /// sums their digests. For what no folder on disk in a test can hold: files only in the cloud, entries with errors.
    static func scan(_ listings: [String: [DirectoryEntry]], rootPath: String = "/Root") -> (tree: ScanTree, summary: ScanSummary) {
        var tree = ScanTree(rootName: "Root", rootPath: rootPath)
        var summary = ScanSummary()
        var stack: [(node: Int32, relative: String)] = [(ScanTree.rootIndex, "")]
        while let (node, relative) = stack.popLast() {
            var listing = digest(listings[relative] ?? [], parentPath: tree.path(of: node), countsLinks: false)
            for (child, item) in tree.merge(&listing, into: node) {
                stack.append((child, relative.isEmpty ? item.name : relative + "/" + item.name))
            }
            summary.absorb(listing)
        }
        tree.computeTotals()
        tree.finishBuilding()
        summary.files = Int(tree.root.fileCount)
        summary.folders = Int(tree.root.folderCount)
        summary.bytes = tree.root.size
        summary.logicalBytes = tree.root.logicalSize
        return (tree, summary)
    }

    /// Lists `folder` of `tree` again with `entries`, as a refresh does, and sums its totals again.
    static func relist(_ folder: Int32, in tree: inout ScanTree, with entries: [DirectoryEntry]) {
        var listing = digest(entries, parentPath: tree.path(of: folder), countsLinks: false)
        _ = tree.replaceContents(of: folder, with: &listing)
        tree.recomputeTotals(dirty: [folder])
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
