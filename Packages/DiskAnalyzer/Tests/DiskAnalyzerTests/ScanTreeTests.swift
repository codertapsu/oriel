@testable import DiskAnalyzer
import Foundation
import Testing

/// The tree's totals, paths and edits.
struct ScanTreeTests {
    private let tree = Fixtures.tree(
        [
            "Movies/trip.mov": 8_000_000,
            "Movies/Old/1999.avi": 3_000_000,
            "Code/app/main.swift": 2_000_000,
            "notes.pdf": 1_500_000,
            "Empty/": 0,
        ],
        small: ["Code": (count: 12, size: 400_000)]
    )

    @Test func foldersSumTheirContents() throws {
        #expect(tree.root.size == 14_900_000)
        #expect(tree.root.fileCount == 4 + 12)
        #expect(tree.root.folderCount == 5)
        let movies = try #require(Fixtures.index("Movies", in: tree))
        #expect(tree[movies].size == 11_000_000)
        #expect(tree[movies].fileCount == 2)
        #expect(tree[movies].folderCount == 1)
        let code = try #require(Fixtures.index("Code", in: tree))
        #expect(tree[code].size == 2_400_000)
    }

    @Test func childrenComeLargestFirst() {
        let names = tree.childrenBySize(of: ScanTree.rootIndex).map { tree.name(of: $0) }
        #expect(names == ["Movies", "Code", "notes.pdf", "Empty"])
    }

    @Test func pathsAreBuiltFromNames() throws {
        let old = try #require(Fixtures.index("Movies/Old/1999.avi", in: tree))
        #expect(tree.path(of: old) == "/Root/Movies/Old/1999.avi")
        #expect(tree.path(of: ScanTree.rootIndex) == "/Root")
        #expect(tree.lineage(of: old).map { tree.name(of: $0) } == ["Root", "Movies", "Old", "1999.avi"])
        #expect(tree.index(ofPath: "/Root/Movies/") == Fixtures.index("Movies", in: tree))
        #expect(tree.index(ofPath: "/Elsewhere/Movies") == nil)
        #expect(tree.nearestIndex(toPath: "/Root/Movies/Old/new.mov") == Fixtures.index("Movies/Old", in: tree))
    }

    @Test func theStartupVolumeShowsFirmlinkedPaths() {
        let firmlinks = FirmlinkMap(parsing: "/Users\tUsers\n/Applications\tApplications\n")
        var tree = ScanTree(rootName: "Macintosh HD", rootPath: FirmlinkMap.dataVolume, firmlinks: firmlinks)
        let users = tree.append(DirectoryDigest.Item(name: "Users", kind: .folder), to: ScanTree.rootIndex)
        let me = tree.append(DirectoryDigest.Item(name: "me", kind: .folder), to: users)
        tree.computeTotals()
        #expect(tree.path(of: me) == "/System/Volumes/Data/Users/me")
        #expect(tree.displayPath(of: me) == "/Users/me")
        #expect(tree.index(ofPath: "/Users/me") == me)
        #expect(tree.index(ofPath: "/System/Volumes/Data/Users/me") == me)
    }

    @Test func removingAnItemUpdatesEveryTotalAbove() throws {
        var tree = tree
        let old = try #require(Fixtures.index("Movies/Old", in: tree))
        tree.remove(old)
        #expect(tree.root.size == 11_900_000)
        #expect(tree.root.folderCount == 4)
        #expect(!tree.contains(old))
        #expect(Fixtures.index("Movies/Old", in: tree) == nil)
        #expect(tree.files(under: ScanTree.rootIndex).count == 3)
        #expect(tree.removedCount == 2)
    }

    @Test func theRootCannotBeRemoved() {
        var tree = tree
        tree.remove(ScanTree.rootIndex)
        #expect(tree.root.size == 14_900_000)
    }

    @Test func replacingAFolderKeepsItsSubfoldersAndReturnsNewOnes() throws {
        var tree = tree
        let movies = try #require(Fixtures.index("Movies", in: tree))
        var digest = DirectoryDigest()
        digest.items = [
            DirectoryDigest.Item(name: "Old", kind: .folder),
            DirectoryDigest.Item(name: "New", kind: .folder, descends: true),
            DirectoryDigest.Item(name: "edit.mov", kind: .file, size: 4_000_000, logicalSize: 4_000_000),
        ]
        let next = tree.replaceContents(of: movies, with: &digest)
        #expect(next.map(\.item.name) == ["New"])
        tree.recomputeTotals(dirty: Set([movies] + next.map(\.index)))
        // trip.mov (8 MB) went, edit.mov (4 MB) came, Old (3 MB) stayed.
        #expect(tree[movies].size == 7_000_000)
        #expect(tree.root.size == 10_900_000)
        #expect(Fixtures.index("Movies/Old/1999.avi", in: tree) != nil)
        #expect(Fixtures.index("Movies/trip.mov", in: tree) == nil)
    }

    /// A file with several hard links is counted once across every listing that goes into the tree: its link in another
    /// folder adds nothing, and the folder that counted it goes on counting it when it is listed again.
    @Test func aHardLinkedFileIsCountedOnceAcrossListings() throws {
        var tree = Fixtures.tree(["A/": 0, "B/": 0])
        let folderA = try #require(Fixtures.index("A", in: tree))
        let folderB = try #require(Fixtures.index("B", in: tree))
        var first = linkListing("x.bin")
        _ = tree.merge(&first, into: folderA)
        var further = linkListing("y.bin")
        _ = tree.replaceContents(of: folderB, with: &further)
        var again = linkListing("x.bin")
        _ = tree.replaceContents(of: folderA, with: &again)
        tree.recomputeTotals(dirty: [folderA, folderB])
        #expect(tree.root.size == 3_000_000)
        #expect(tree[folderA].size == 3_000_000)
        #expect(tree.root.fileCount == 2)
        #expect(further.duplicateLinks == 1)
        #expect(further.categoryTotals.totalBytes == 0)
        #expect(again.duplicateLinks == 0)
        #expect(again.categoryTotals.totalBytes == 3_000_000)
    }

    /// Compaction renumbers the nodes that carry the files' sizes. When a file's counted link is removed, the folder
    /// holding another link is handed out, once, to be read again, and that listing counts the file.
    @Test func theCountedLinksFollowCompactionAndRemoval() throws {
        var tree = Fixtures.tree(["A/": 0, "B/": 0, "Gone/old.bin": 2_000_000])
        var counted = linkListing("x.bin")
        _ = try tree.merge(&counted, into: #require(Fixtures.index("A", in: tree)))
        var held = linkListing("y.bin")
        _ = try tree.merge(&held, into: #require(Fixtures.index("B", in: tree)))
        try tree.remove(#require(Fixtures.index("Gone", in: tree)))
        tree = tree.compacted()
        let folderB = try #require(Fixtures.index("B", in: tree))
        var again = linkListing("y.bin")
        _ = tree.replaceContents(of: folderB, with: &again)
        #expect(again.duplicateLinks == 1)
        #expect(tree.foldersToRecount().isEmpty)

        try tree.remove(#require(Fixtures.index("A/x.bin", in: tree)))
        #expect(tree.foldersToRecount() == [folderB])
        #expect(tree.foldersToRecount().isEmpty)
        var recount = linkListing("y.bin")
        _ = tree.replaceContents(of: folderB, with: &recount)
        tree.recomputeTotals(dirty: [folderB])
        #expect(recount.duplicateLinks == 0)
        #expect(tree.root.size == 3_000_000)
        #expect(tree[folderB].size == 3_000_000)
    }

    /// The listing of a folder holding `name`, a link of a 3 MB file with another link.
    private func linkListing(_ name: String) -> DirectoryDigest {
        Fixtures.digest([Fixtures.entry(name, size: 3_000_000, inode: 42, links: 2)], countsLinks: false)
    }

    @Test func compactionDropsRemovedNodesAndKeepsEverythingElse() throws {
        var tree = tree
        try tree.remove(#require(Fixtures.index("Movies", in: tree)))
        let compacted = tree.compacted()
        #expect(compacted.count == tree.count - tree.removedCount)
        #expect(compacted.removedCount == 0)
        #expect(compacted.generation == tree.generation + 1)
        #expect(compacted.root.size == tree.root.size)
        let main = try #require(Fixtures.index("Code/app/main.swift", in: compacted))
        #expect(compacted[main].size == 2_000_000)
        #expect(compacted.path(of: main) == "/Root/Code/app/main.swift")
        for index in 1 ..< compacted.count {
            #expect(compacted.nodes[index].parent < Int32(index), "a parent comes before its children")
        }
    }

    @Test func largestFilesAreFoundAcrossTheTree() {
        let names = tree.largestFiles(under: ScanTree.rootIndex, limit: 2).map { tree.name(of: $0) }
        #expect(names == ["trip.mov", "1999.avi"])
        #expect(tree.largestFiles(under: ScanTree.rootIndex, limit: 10).count == 4)
    }

    @Test func largestFilesBelowAFolderStayBelowIt() throws {
        let movies = try #require(Fixtures.index("Movies", in: tree))
        #expect(tree.largestFiles(under: movies, limit: 10).map { tree.name(of: $0) } == ["trip.mov", "1999.avi"])
    }

    @Test func searchMatchesEveryWordIgnoringCaseAndAccents() {
        let tree = Fixtures.tree(["Résumé 2024.pdf": 2_000_000, "Photos/résumé.jpg": 2_000_000, "other.txt": 2_000_000])
        #expect(tree.search("resume", under: ScanTree.rootIndex).count == 2)
        #expect(tree.search("RESUME 2024", under: ScanTree.rootIndex).map { tree.name(of: $0) } == ["Résumé 2024.pdf"])
        #expect(tree.search("photos", under: ScanTree.rootIndex).map { tree.name(of: $0) } == ["Photos"])
        #expect(tree.search("  ", under: ScanTree.rootIndex).isEmpty)
    }

    @Test func aRootWithoutANameIsFine() {
        var tree = ScanTree(rootName: "", rootPath: "/Root")
        tree.append(DirectoryDigest.Item(name: "a.bin", kind: .file, size: 5, logicalSize: 5), to: ScanTree.rootIndex)
        var small = DirectoryDigest.SmallFiles()
        small.count = 2
        small.size = 3
        tree.append(small, to: ScanTree.rootIndex)
        tree.computeTotals()
        #expect(tree.root.size == 8)
        #expect(tree.name(of: ScanTree.rootIndex).isEmpty)
    }

    @Test func datesSurviveTheCompactEncoding() {
        let date = Date(timeIntervalSince1970: 1_700_000_123)
        #expect(ScanNode.decode(ScanNode.encode(date)) == date)
        #expect(ScanNode.decode(ScanNode.encode(nil)) == nil)
        #expect(ScanNode.encode(secondsSince1970: 0) == ScanNode.unknownDate)
    }
}
