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

    static func digest(
        _ entries: [DirectoryEntry],
        parentPath: String = "/Root",
        options: ScanOptions = ScanOptions(),
        inherited: FileCategory? = nil,
        registry: HardLinkRegistry = HardLinkRegistry(),
        canCross: @escaping (String) -> Bool = { _ in false }
    ) -> DirectoryDigest {
        var categories = FileCategoryCache()
        var registry = registry
        return DirectoryDigest.make(
            entries: entries,
            parentPath: parentPath,
            inheritedCategory: inherited,
            options: options,
            categories: &categories,
            isFirstLink: { registry.isFirstLink(device: $0, inode: $1) },
            canCrossInto: canCross
        )
    }

    /// The index of the node at `relative` in `tree`.
    static func index(_ relative: String, in tree: ScanTree) -> Int32? {
        tree.index(ofPath: relative.isEmpty ? tree.rootPath : tree.rootPath + "/" + relative)
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
