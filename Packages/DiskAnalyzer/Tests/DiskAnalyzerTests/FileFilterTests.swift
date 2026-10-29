@testable import DiskAnalyzer
import Foundation
import Testing

/// Filtering and sorting the file lists.
struct FileFilterTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var yearAgo: Date {
        now.addingTimeInterval(-366 * 86400)
    }

    private var tree: ScanTree {
        Fixtures.tree(
            [
                "Movies/new.mov": 9_000_000,
                "Movies/old.mov": 4_000_000,
                "Archive/old.zip": 6_000_000,
                "photo.heic": 2_000_000,
            ],
            modified: [
                "Movies/new.mov": now.addingTimeInterval(-86400),
                "Movies/old.mov": now.addingTimeInterval(-800 * 86400),
                "Archive/old.zip": now.addingTimeInterval(-400 * 86400),
                "photo.heic": now.addingTimeInterval(-10 * 86400),
            ]
        )
    }

    private func names(_ filter: FileFilter, lastOpened: [String: Date] = [:]) -> [String] {
        let tree = tree
        return tree.files(under: ScanTree.rootIndex)
            .filter { filter.accepts(tree[$0], name: tree.name(of: $0), lastOpened: lastOpened[tree.name(of: $0)]) }
            .map { tree.name(of: $0) }
            .sorted()
    }

    @Test func filtersByCategory() {
        var filter = FileFilter()
        filter.categories = [.video]
        #expect(names(filter) == ["new.mov", "old.mov"])
        filter.categories = [.archive, .image]
        #expect(names(filter) == ["old.zip", "photo.heic"])
    }

    @Test func filtersBySize() {
        var filter = FileFilter()
        filter.minimumSize = 5_000_000
        #expect(names(filter) == ["new.mov", "old.zip"])
    }

    @Test func filtersByModificationDate() {
        var filter = FileFilter()
        filter.modifiedBefore = yearAgo
        #expect(names(filter) == ["old.mov", "old.zip"])
    }

    @Test func aFileOpenedRecentlyIsNotOldEvenIfItWasModifiedLongAgo() {
        var filter = FileFilter()
        filter.lastUsedBefore = yearAgo
        #expect(names(filter) == ["old.mov", "old.zip"])
        #expect(names(filter, lastOpened: ["old.mov": now.addingTimeInterval(-3 * 86400)]) == ["old.zip"])
    }

    @Test func anUnknownDateIsNeverOld() {
        let node = ScanNode(name: 0, parent: 0, kind: .file)
        #expect(FileFilter.lastUsed(node, lastOpened: nil) == .distantFuture)
    }

    @Test func filtersByNameAndCombinesEverything() {
        var filter = FileFilter()
        filter.nameQuery = "OLD"
        #expect(names(filter) == ["old.mov", "old.zip"])
        filter.categories = [.archive]
        #expect(names(filter) == ["old.zip"])
        #expect(!filter.isEmpty)
        #expect(FileFilter().isEmpty)
    }

    @Test func cloudOnlyFilesPassTheSizeFilterByContentSize() {
        var node = ScanNode(name: 0, parent: 0, kind: .file)
        node.flags = [.cloudOnly]
        node.logicalSize = 8_000_000
        var filter = FileFilter()
        filter.minimumSize = 5_000_000
        #expect(filter.accepts(node, name: "x.mov"))
        filter.includesCloudOnly = false
        #expect(!filter.accepts(node, name: "x.mov"))
    }

    @Test(arguments: [
        (FileSort.Key.size, false, ["new.mov", "old.zip", "old.mov", "photo.heic"]),
        (FileSort.Key.size, true, ["photo.heic", "old.mov", "old.zip", "new.mov"]),
        (FileSort.Key.name, true, ["new.mov", "old.mov", "old.zip", "photo.heic"]),
        (FileSort.Key.modified, false, ["new.mov", "photo.heic", "old.zip", "old.mov"]),
        (FileSort.Key.folder, true, ["photo.heic", "old.zip", "new.mov", "old.mov"]),
    ])
    func sortsByEachKey(_ key: FileSort.Key, _ ascending: Bool, _ expected: [String]) {
        let tree = tree
        let sorted = FileSort(key: key, ascending: ascending).sorted(tree.files(under: ScanTree.rootIndex), in: tree)
        #expect(sorted.map { tree.name(of: $0) } == expected)
    }
}
