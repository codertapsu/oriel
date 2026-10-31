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

    /// Every folder whose smaller files hold a further link of a file is remembered, not only the one listed last: when
    /// the folder whose link carried the file's size goes with either of the two others, the one left is handed out to be
    /// read again, through compaction too, and counts the file.
    @Test(arguments: ["B", "C"])
    func everyFolderHoldingAFurtherLinkIsRemembered(_ alsoGone: String) throws {
        var tree = Fixtures.tree(["A/": 0, "B/": 0, "C/": 0, "Gone/old.bin": 2_000_000])
        for folder in ["A", "B", "C"] {
            var listing = linkListing(folder.lowercased() + ".bin", links: 3)
            _ = try tree.merge(&listing, into: #require(Fixtures.index(folder, in: tree)))
        }
        try tree.remove(#require(Fixtures.index("Gone", in: tree)))
        tree = tree.compacted()
        try tree.remove(#require(Fixtures.index("A", in: tree)))
        try tree.remove(#require(Fixtures.index(alsoGone, in: tree)))
        let left = alsoGone == "B" ? "C" : "B"
        let folder = try #require(Fixtures.index(left, in: tree))
        #expect(tree.foldersToRecount() == [folder])
        #expect(tree.foldersToRecount().isEmpty)
        var recount = linkListing(left.lowercased() + ".bin", links: 3)
        _ = tree.replaceContents(of: folder, with: &recount)
        tree.recomputeTotals(dirty: [folder])
        #expect(recount.duplicateLinks == 0)
        #expect(tree.root.size == 3_000_000)
        #expect(tree[folder].size == 3_000_000)
    }

    /// A folder handed out that no longer holds the link, read again, does not count the file, so the next time the
    /// folders to read again are asked for, the other folder holding one is handed out and counts it.
    @Test func theNextFolderHoldingALinkIsHandedOutWhenOneNoLongerHoldsIt() throws {
        var tree = Fixtures.tree(["A/": 0, "B/": 0, "C/": 0])
        for folder in ["A", "B", "C"] {
            var listing = linkListing(folder.lowercased() + ".bin", links: 3)
            _ = try tree.merge(&listing, into: #require(Fixtures.index(folder, in: tree)))
        }
        let holders = try Set(["B", "C"].map { try #require(Fixtures.index($0, in: tree)) })
        try tree.remove(#require(Fixtures.index("A/a.bin", in: tree)))
        let handedOut = tree.foldersToRecount()
        #expect(handedOut.count == 1)
        let first = try #require(handedOut.first)
        var emptied = DirectoryDigest()
        _ = tree.replaceContents(of: first, with: &emptied)
        let second = try #require(tree.foldersToRecount().first)
        #expect(Set([first, second]) == holders)
        var recount = linkListing(tree.name(of: second).lowercased() + ".bin", links: 3)
        _ = tree.replaceContents(of: second, with: &recount)
        tree.recomputeTotals(dirty: [first, second])
        #expect(recount.duplicateLinks == 0)
        #expect(tree.root.size == 3_000_000)
        #expect(tree.foldersToRecount().isEmpty)
    }

    /// The listing of a folder holding `name`, a link of a 3 MB file with `links` links in all.
    private func linkListing(_ name: String, links: UInt32 = 2) -> DirectoryDigest {
        Fixtures.digest([Fixtures.entry(name, size: 3_000_000, inode: 42, links: links)], countsLinks: false)
    }

    /// An aggregate of smaller files keeps the kinds of the files it sums, so File Types and the further links are summed
    /// from the tree as the scan summed them from its listings; they leave the sums with the aggregate.
    @Test func anAggregateKeepsTheKindsOfItsFilesUntilItGoes() throws {
        var tree = Fixtures.tree(["Music/": 0, "Work/": 0])
        let music = try #require(Fixtures.index("Music", in: tree))
        let work = try #require(Fixtures.index("Work", in: tree))
        var songs = Fixtures.digest([Fixtures.entry("song.mp3", size: 9000, inode: 42, links: 2)], countsLinks: false)
        _ = tree.merge(&songs, into: music)
        var listing = Fixtures.digest([
            Fixtures.entry("main.swift", size: 3000),
            Fixtures.entry("photo.png", size: 20000),
            Fixtures.entry("movie.mov", size: 5_000_000),
            Fixtures.entry("song again.mp3", size: 9000, inode: 42, links: 2),
            Fixtures.entry("shortcut", .symlink),
        ], countsLinks: false)
        _ = tree.merge(&listing, into: work)
        var scanned = ScanSummary()
        scanned.absorb(songs)
        scanned.absorb(listing)
        var summary = ScanSummary()
        summary.recountListings(in: tree)
        #expect(summary.categories == scanned.categories)
        #expect(summary.duplicateLinks == 1)
        #expect(summary.categories.totalCount == 5)
        #expect(summary.categories.count(of: .audio) == 2)
        #expect(summary.categories.bytes(of: .audio) == 9000)

        tree.remove(work)
        summary.recountListings(in: tree)
        #expect(summary.categories == songs.categoryTotals)
        #expect(summary.duplicateLinks == 0)
    }

    /// The kinds go with their aggregate when its folder is listed again, and follow it through compaction, which
    /// renumbers them and drops those of the aggregates taken out.
    @Test func theKindsFollowTheirAggregateThroughReplacementAndCompaction() throws {
        var tree = Fixtures.tree(["Gone/old.mov": 2_000_000, "Work/": 0])
        let work = try #require(Fixtures.index("Work", in: tree))
        var first = Fixtures.digest([Fixtures.entry("a.png", size: 1000), Fixtures.entry("b.png", size: 2000)])
        _ = tree.merge(&first, into: work)
        var again = Fixtures.digest([Fixtures.entry("c.swift", size: 4000), Fixtures.entry("d.txt", size: 500)])
        _ = tree.replaceContents(of: work, with: &again)
        try tree.remove(#require(Fixtures.index("Gone", in: tree)))
        var summary = ScanSummary()
        summary.recountListings(in: tree)
        #expect(summary.categories == again.categoryTotals)

        let compacted = tree.compacted()
        var after = ScanSummary()
        after.recountListings(in: compacted)
        #expect(after.categories == again.categoryTotals)
        #expect(compacted.smallFileKinds.byteCount < tree.smallFileKinds.byteCount)
    }

    /// Files only in the cloud, kept one by one (a 900 MB lecture) or among the smaller files, and entries the file system
    /// reported errors for are summed from the tree after every edit as a fresh scan of the same folders sums them: a
    /// folder listed again counts what its new listing holds and no longer what its old one held, a removal takes out what
    /// it removed, and compaction, which moves Lectures, moves its count with it. A test cannot make either on disk, so the
    /// folders are in memory.
    @Test func theFilesOnlyInTheCloudAndTheFailedEntriesAreSummedFromTheTree() throws {
        var listings: [String: [DirectoryEntry]] = [
            "": [Fixtures.entry("Music", .directory), Fixtures.entry("Lectures", .directory), Fixtures.failedEntry("lost")],
            "Lectures": [
                Fixtures.cloudFile("week 1.mp4", content: 900_000_000),
                Fixtures.cloudFile("notes.pdf", content: 300_000),
                Fixtures.entry("summary.txt", size: 4000),
                Fixtures.failedEntry("broken"),
            ],
            "Music": [
                Fixtures.cloudFile("song.m4a", content: 7_000_000),
                Fixtures.cloudFile("demo.m4a", content: 600_000),
                Fixtures.failedEntry("scratched"),
            ],
        ]
        let scanned = Fixtures.scan(listings)
        #expect(scanned.summary.cloudOnlyFiles == 4)
        #expect(scanned.summary.cloudOnlyBytes == 907_900_000)
        #expect(scanned.summary.entryErrors == 3)
        var tree = scanned.tree
        func expectSummedAsAFreshScan(_ tree: ScanTree) {
            let summary = DiskAnalyzerModel.recounting(tree, summary: scanned.summary, volume: nil).summary
            let fresh = Fixtures.scan(listings).summary
            #expect(summary.cloudOnlyFiles == fresh.cloudOnlyFiles)
            #expect(summary.cloudOnlyBytes == fresh.cloudOnlyBytes)
            #expect(summary.entryErrors == fresh.entryErrors)
        }

        // The lecture was downloaded and the notes removed; slides came, only in the cloud, and two entries failed.
        listings["Lectures"] = [
            Fixtures.entry("week 1.mp4", size: 900_000_000),
            Fixtures.cloudFile("slides.key", content: 450_000),
            Fixtures.entry("summary.txt", size: 4000),
            Fixtures.failedEntry("other"),
            Fixtures.failedEntry("another"),
        ]
        try Fixtures.relist(#require(Fixtures.index("Lectures", in: tree)), in: &tree, with: listings["Lectures"] ?? [])
        expectSummedAsAFreshScan(tree)

        try tree.remove(#require(Fixtures.index("Music", in: tree)))
        listings["Music"] = nil
        listings[""] = [Fixtures.entry("Lectures", .directory), Fixtures.failedEntry("lost")]
        expectSummedAsAFreshScan(tree)

        var compacted = tree.compacted()
        #expect(Fixtures.index("Lectures", in: compacted) != Fixtures.index("Lectures", in: tree))
        expectSummedAsAFreshScan(compacted)
        listings["Lectures"] = [Fixtures.failedEntry("last")]
        try Fixtures.relist(#require(Fixtures.index("Lectures", in: compacted)), in: &compacted, with: listings["Lectures"] ?? [])
        expectSummedAsAFreshScan(compacted)
    }

    /// The kinds are kept as variable-length numbers: a folder's smaller files of one kind take 5 bytes, and nothing more
    /// for having no files only in the cloud. Large counts and sizes, every category, further links and files only in the
    /// cloud come back exact, after renumbering too.
    @Test func theKindsSurviveTheirCompactForm() {
        var code = DirectoryDigest.SmallFiles()
        code.categories.add(.code, bytes: 0, count: 1)
        var single = SmallFileKinds()
        single.record(code, at: 3)
        #expect(single.byteCount == 5)

        var everything = DirectoryDigest.SmallFiles()
        for category in FileCategory.allCases {
            everything.categories.add(category, bytes: 5_000_000_000 + Int64(category.rawValue), count: 300 + Int(category.rawValue))
        }
        everything.duplicateLinks = 7
        everything.cloudOnlyFiles = 40
        everything.cloudOnlyBytes = 70_000_000_000
        var links = DirectoryDigest.SmallFiles()
        links.count = 3 // symbolic links only: no kind to keep
        var cloud = DirectoryDigest.SmallFiles()
        cloud.categories.add(.document, bytes: 0, count: 2)
        cloud.cloudOnlyFiles = 2
        cloud.cloudOnlyBytes = 600_000
        var kinds = SmallFileKinds()
        kinds.record(everything, at: 5)
        kinds.record(links, at: 6)
        kinds.record(cloud, at: 8)
        kinds.record(code, at: 70000)
        var expected = everything.categories
        expected.merge(cloud.categories)
        expected.merge(code.categories)
        let all = kinds.totals { _ in true }
        #expect(all.categories == expected)
        #expect(all.duplicateLinks == 7)
        #expect(all.cloudOnlyFiles == 42)
        #expect(all.cloudOnlyBytes == 70_000_600_000)
        #expect(kinds.totals { $0 == 70000 } == SmallFileKinds.Totals(categories: code.categories))
        #expect(kinds.totals { $0 == 8 }.cloudOnlyBytes == 600_000)

        // Compaction turns their order around and drops what it did not keep.
        let renumbered = kinds.renumbered(by: [70000: 1, 8: 4, 5: 9])
        #expect(renumbered.totals { _ in true } == all)
        #expect(renumbered.totals { $0 == 1 }.categories == code.categories)
        #expect(renumbered.totals { $0 == 4 }.cloudOnlyFiles == 2)
        #expect(renumbered.totals { $0 == 9 }.duplicateLinks == 7)
        #expect(renumbered.totals { $0 == 9 }.cloudOnlyBytes == 70_000_000_000)
        #expect(kinds.renumbered(by: [70000: 2]).totals { _ in true } == SmallFileKinds.Totals(categories: code.categories))
    }

    /// Beside a node's 56 bytes (PLAN §9), the kinds take a few bytes a node: here 3,000 folders whose smaller files are of
    /// two to four kinds each, as source, pictures, documents, caches and build products are.
    @Test func theKindsTakeAFewBytesANode() {
        let profiles: [[String]] = [
            ["swift", "swift", "json", "md", ""], ["js", "json", "md", "ts", "map"], ["png", "jpg", "heic"],
            ["txt", "pdf", "md", "csv"], ["", "db", "plist"], ["mp3", "m4a", "jpg"], ["o", "d", "swiftmodule", "json"],
            ["zip", "gz", "txt"],
        ]
        var tree = ScanTree(rootName: "Root", rootPath: "/Root")
        for number in 0 ..< 3000 {
            let profile = profiles[number % profiles.count]
            let entries = (0 ..< 8 + number % 33).map { file in
                let ext = profile[(number + file) % profile.count]
                return Fixtures.entry("file \(file)" + (ext.isEmpty ? "" : "." + ext), size: Int64((number * 131 + file * 977) % 60000))
            }
            var digest = Fixtures.digest(entries, parentPath: "/Root/Folder \(number)", countsLinks: false)
            let folder = tree.append(DirectoryDigest.Item(name: "Folder \(number)", kind: .folder), to: ScanTree.rootIndex)
            _ = tree.merge(&digest, into: folder)
        }
        let perNode = Double(tree.smallFileKinds.byteCount) / Double(tree.count)
        #expect(perNode < 8, "\(perNode) bytes a node")
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
