import Darwin
@testable import DiskAnalyzer
import Foundation
import Testing

/// Read as Administrator, as far as it goes without a password: the request handed to the root process, that process's
/// listing (run as the user here), and how its listings go into a scan. No test shows the password prompt.
struct ElevatedReadTests {
    private typealias Item = DirectoryDigest.Item

    @Test func theRequestTravelsAsArgumentsAndBack() {
        var options = ScanOptions()
        options.smallFileThreshold = 500_000
        options.includesHiddenFiles = true
        options.exclusions = ExclusionRules(paths: ["/private/var/db/uuidtext"], names: ["node_modules"])
        let request = ElevatedRead.Request(folders: ["/private/var/db/locked", "/Users/other user"], options: options)
        #expect(ElevatedRead.Request(arguments: request.arguments) == request)
        let plain = ElevatedRead.Request(folders: ["/x"])
        #expect(ElevatedRead.Request(arguments: plain.arguments) == plain)
    }

    @Test(arguments: [
        [String](),
        ["--"],
        ["/x"],
        ["--", "relative/path"],
        ["--threshold", "-1", "--", "/x"],
        ["--threshold"],
        ["--frobnicate", "--", "/x"],
        ["--exclude-name"],
    ])
    func wrongArgumentsAreRefused(_ arguments: [String]) {
        #expect(ElevatedRead.Request(arguments: arguments) == nil)
    }

    @Test func onlyItsOwnArgumentInFirstPlaceStartsTheListingMode() {
        #expect(ElevatedRead.runIfRequested(["Oriel"]) == nil)
        #expect(ElevatedRead.runIfRequested(["Oriel", "--self-test"]) == nil)
        #expect(ElevatedRead.runIfRequested(["Oriel", "--self-test", ElevatedRead.argument]) == nil)
        #expect(ElevatedRead.runIfRequested(["Oriel", ElevatedRead.argument, "--bogus"]) == 64)
    }

    @Test func theListingModeReadsWhatAScanWouldAndSaysWhatItCannot() throws {
        let folder = try TemporaryFolder()
        try folder.file("A/big.bin", size: 2_000_000)
        try folder.file("A/B/small.txt", size: 10)
        try folder.file("Locked/secret.bin", size: 2_000_000)
        #expect(chmod(folder.path + "/Locked", 0) == 0)
        defer { chmod(folder.path + "/Locked", 0o755) }
        let result = ElevatedRead.read(ElevatedRead.Request(folders: [folder.path]))
        let byPath = Dictionary(uniqueKeysWithValues: result.listings.map { ($0.path, $0) })
        #expect(Set(byPath.keys) == [folder.path, folder.path + "/A", folder.path + "/A/B", folder.path + "/Locked"])
        #expect(byPath[folder.path + "/Locked"]?.error == EACCES)
        #expect(byPath[folder.path + "/A"]?.digest?.items.map(\.name).sorted() == ["B", "big.bin"])
        #expect(byPath[folder.path + "/A/B"]?.digest?.small.count == 1)
    }

    /// The helper sets the flag when Oriel stops waiting; the listing reads nothing more.
    @Test func aStoppedListingReadsNoFurther() throws {
        let folder = try TemporaryFolder()
        try folder.file("A/big.bin", size: 2_000_000)
        let cancellation = CancellationFlag()
        cancellation.cancel()
        #expect(ElevatedRead.read(ElevatedRead.Request(folders: [folder.path]), cancellation: cancellation).listings.isEmpty)
    }

    /// Listings in an earlier format are refused: before the smaller files came with their files only in the cloud (3) or
    /// their kinds (2), the scan could not sum those again after an edit, and before files with several hard links came
    /// uncounted (1), it could not count those links against its own. So are listings in any format but this Oriel's.
    @Test func listingsInAnotherFormatAreRefused() throws {
        var digest = DirectoryDigest()
        digest.links = [DirectoryDigest.Link(file: .init(device: 1, inode: 2), item: Item(name: "a", kind: .file), isKept: false)]
        digest.small.add(Fixtures.entry("b.txt", size: 10), category: .document)
        digest.small.add(Fixtures.cloudFile("c.pdf", content: 20000), category: .document)
        let current = try JSONEncoder().encode(ElevatedRead.Result(listings: [ElevatedRead.Listing(path: "/x", digest: digest)]))
        #expect(ElevatedRead.result(from: current)?.listings.first?.digest == digest)
        #expect(ElevatedRead.result(from: current)?.listings.first?.digest?.small.cloudOnlyBytes == 20000)
        // Format 3 sent the files only in the cloud summed over the digest, none with the smaller files.
        let third = try earlier(current, version: 3) { digest in
            var small = digest["small"] as? [String: Any] ?? [:]
            digest["cloudOnlyFiles"] = small.removeValue(forKey: "cloudOnlyFiles")
            digest["cloudOnlyBytes"] = small.removeValue(forKey: "cloudOnlyBytes")
            digest["small"] = small
        }
        #expect(ElevatedRead.result(from: third) == nil)
        // Format 2 sent the kinds summed over the digest, none with the smaller files.
        let second = try earlier(third, version: 2) { digest in
            var small = digest["small"] as? [String: Any] ?? [:]
            digest["categoryTotals"] = small.removeValue(forKey: "categories")
            digest["duplicateLinks"] = small.removeValue(forKey: "duplicateLinks")
            digest["small"] = small
        }
        #expect(ElevatedRead.result(from: second) == nil)
        // Format 1 counted the links before sending the listings.
        let first = try earlier(second, version: 1) { $0["links"] = nil }
        #expect(ElevatedRead.result(from: first) == nil)
        let newer = ElevatedRead.Result(version: ElevatedRead.version + 1, listings: [])
        #expect(try ElevatedRead.result(from: JSONEncoder().encode(newer)) == nil)
    }

    /// The answer `data` as an earlier Oriel wrote it: in `version`, each listing's digest changed by `change`.
    private func earlier(_ data: Data, version: Int, change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let listings = try #require(object["listings"] as? [[String: Any]])
        object["listings"] = try listings.map { listing in
            var listing = listing
            var digest = try #require(listing["digest"] as? [String: Any])
            change(&digest)
            listing["digest"] = digest
            return listing
        }
        object["version"] = version
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test func theListingsSurviveJSON() throws {
        let folder = try TemporaryFolder()
        try folder.file("x/é ü 名前 \"quoted\".bin", size: 2_000_000)
        let result = ElevatedRead.read(ElevatedRead.Request(folders: [folder.path]))
        let decoded = try JSONDecoder().decode(ElevatedRead.Result.self, from: JSONEncoder().encode(result))
        #expect(decoded == result)
    }

    @Test func whatWasReadGoesIntoTheScanWhereTheFolderWas() throws {
        var tree = Fixtures.tree(["Open/a.bin": 2_000_000, "Locked/": 0])
        let locked = try #require(Fixtures.index("Locked", in: tree))
        tree.setUnreadable(.needsAdministrator, at: locked)
        var summary = ScanSummary()
        summary.recountUnreadable(in: tree)
        #expect(summary.administratorFolders == 1)

        // What root read: the folder, a folder inside, and one System Integrity Protection still kept closed.
        var top = DirectoryDigest()
        top.items = [
            Item(name: "secret.bin", kind: .file, size: 3_000_000, logicalSize: 3_000_000),
            Item(name: "Inner", kind: .folder, descends: true),
            Item(name: "Vault", kind: .folder, descends: true),
        ]
        var inner = DirectoryDigest()
        inner.items = [Item(name: "deep.bin", kind: .file, size: 1_000_000, logicalSize: 1_000_000)]
        let result = ElevatedRead.Result(listings: [
            ElevatedRead.Listing(path: "/Root/Locked", digest: top),
            ElevatedRead.Listing(path: "/Root/Locked/Inner", digest: inner),
            ElevatedRead.Listing(path: "/Root/Locked/Vault", error: EPERM),
        ])
        let dirty = ElevatedRead.apply(result, folders: ["/Root/Locked"], to: &tree, summary: &summary)
        tree.recomputeTotals(dirty: dirty)
        summary.recountUnreadable(in: tree)

        #expect(tree[locked].size == 4_000_000)
        #expect(tree[locked].flags.contains(.readAsAdministrator))
        #expect(tree[locked].flags.isDisjoint(with: UnreadableReason.allFlags))
        let deep = try #require(Fixtures.index("Locked/Inner/deep.bin", in: tree))
        #expect(tree[deep].flags.contains(.readAsAdministrator))
        let vault = try #require(Fixtures.index("Locked/Vault", in: tree))
        #expect(tree[vault].flags.isSuperset(of: [.unreadable, .protectedByMacOS, .readAsAdministrator]))
        #expect(summary.administratorFolders == 0)
        #expect(summary.protectedFolders == 1)
        #expect(summary.samples(.protectedByMacOS) == ["/Root/Locked/Vault"])
        #expect(tree.root.size == 6_000_000)
    }

    /// A refresh that reads the folder around one read as an administrator all the way down, as when the file system
    /// dropped events there, keeps what root read: the user's rights would only find it closed again.
    @Test func aDeepRefreshKeepsWhatWasReadAsAdministrator() async throws {
        let folder = try TemporaryFolder()
        try folder.file("Open/a.bin", size: 1_000_000)
        try folder.file("Locked/secret.bin", size: 3_000_000)
        #expect(chmod(folder.path + "/Locked", 0) == 0)
        defer { chmod(folder.path + "/Locked", 0o755) }
        let target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "Fixture", firmlinks: .empty)
        let scanned = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag())
        var digest = DirectoryDigest()
        digest.items = [Item(name: "secret.bin", kind: .file, size: 3_000_000, logicalSize: 3_000_000)]
        let result = ElevatedRead.Result(listings: [ElevatedRead.Listing(path: folder.path + "/Locked", digest: digest)])
        let read = DiskAnalyzerModel.adding(
            result, folders: [folder.path + "/Locked"], to: scanned.tree, summary: scanned.summary, volume: nil
        )
        #expect(read.summary.administratorFolders == 0)

        let refreshed = await ScanEngine.refresh(
            read.tree, folders: [], recursive: [ScanTree.rootIndex], options: ScanOptions(), cancellation: CancellationFlag()
        )
        let tree = refreshed.tree
        let locked = try #require(tree.index(ofPath: folder.path + "/Locked"))
        #expect(tree[locked].flags.contains(.readAsAdministrator))
        #expect(tree[locked].flags.isDisjoint(with: UnreadableReason.allFlags))
        #expect(tree[locked].size == 3_000_000)
        #expect(tree.index(ofPath: folder.path + "/Locked/secret.bin") != nil)
        #expect(tree.root.size == read.tree.root.size)
    }

    /// A folder read as an administrator that holds a link of a file the scan counted elsewhere adds nothing for it, as
    /// a scan of the whole would: the listing says which file each link is, and they are counted against the scan's.
    @Test func whatWasReadCountsAFileCountedElsewhereOnce() async throws {
        let folder = try TemporaryFolder()
        let original = try folder.file("Open/original.bin", size: 4_000_000)
        let own = try folder.file("Locked/own.bin", size: 2_000_000)
        #expect(link(original.path, folder.path + "/Locked/link.bin") == 0)
        let expected = Fixtures.allocated(original) + Fixtures.allocated(own)
        // What root lists, read here while the folder is still open, and sent as the helper sends it.
        let listed = ElevatedRead.read(ElevatedRead.Request(folders: [folder.path + "/Locked"]))
        let result = try JSONDecoder().decode(ElevatedRead.Result.self, from: JSONEncoder().encode(listed))
        #expect(chmod(folder.path + "/Locked", 0) == 0)
        defer { chmod(folder.path + "/Locked", 0o755) }
        let target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "Fixture", firmlinks: .empty)
        let scanned = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag())
        let read = DiskAnalyzerModel.adding(
            result, folders: [folder.path + "/Locked"], to: scanned.tree, summary: scanned.summary, volume: nil
        )
        #expect(read.tree.root.size == expected)
        #expect(read.tree.root.fileCount == 3)
        #expect(read.summary.duplicateLinks == 1)
        #expect(read.summary.categories.totalBytes == expected)
    }

    /// What root read was part of the volume's Other space, which is summed again, so the volume still adds up. A scan
    /// stopped part way gets no Other space, as after the scan, since most of what it holds would be in it.
    @Test(arguments: [false, true])
    func whatWasReadIsTakenOutOfOtherSpace(stopped: Bool) throws {
        var tree = Fixtures.tree(["Open/a.bin": 2_000_000, "Locked/": 0])
        try tree.setUnreadable(.needsAdministrator, at: #require(Fixtures.index("Locked", in: tree)))
        var summary = ScanSummary()
        summary.recountUnreadable(in: tree)
        summary.wasCancelled = stopped
        let volume = Fixtures.volume(used: 1_000_000_000)
        if !stopped {
            tree = DiskAnalyzerModel.addingVolumeBlocks(to: tree, volume: volume)
            #expect(tree.root.size == volume.usage.used)
        }
        var digest = DirectoryDigest()
        digest.items = [Item(name: "secret.bin", kind: .file, size: 300_000_000, logicalSize: 300_000_000)]
        let result = ElevatedRead.Result(listings: [ElevatedRead.Listing(path: "/Root/Locked", digest: digest)])
        let read = DiskAnalyzerModel.adding(result, folders: ["/Root/Locked"], to: tree, summary: summary, volume: volume)
        let other = read.tree.children(of: ScanTree.rootIndex).first { read.tree[$0].kind == .unaccounted }
        #expect(read.tree.root.size == (stopped ? 302_000_000 : volume.usage.used))
        #expect(other.map { read.tree[$0].size } == (stopped ? nil : 698_000_000))
        #expect(read.summary.bytes == read.tree.root.size)
    }

    /// A folder a refresh found closed keeps what it held before; what root reads replaces that rather than adding to it.
    @Test func whatWasReadReplacesWhatAFolderHeldBeforeItClosed() throws {
        var tree = Fixtures.tree(["Open/a.bin": 2_000_000, "Locked/old.bin": 5_000_000])
        let locked = try #require(Fixtures.index("Locked", in: tree))
        tree.setUnreadable(.needsAdministrator, at: locked)
        var digest = DirectoryDigest()
        digest.items = [Item(name: "secret.bin", kind: .file, size: 3_000_000, logicalSize: 3_000_000)]
        let result = ElevatedRead.Result(listings: [ElevatedRead.Listing(path: "/Root/Locked", digest: digest)])
        var summary = ScanSummary()
        let dirty = ElevatedRead.apply(result, folders: ["/Root/Locked"], to: &tree, summary: &summary)
        tree.recomputeTotals(dirty: dirty)
        #expect(tree[locked].size == 3_000_000)
        #expect(Fixtures.index("Locked/old.bin", in: tree) == nil)
        #expect(tree.root.size == 5_000_000)
    }

    /// What root reads replaces what the folder held in File Types too: the kinds of the files that went are taken out and
    /// those root found are counted, as a fresh scan of the same files counts them, a file with a link elsewhere once.
    @Test func whatWasReadReplacesTheFileTypesOfWhatAFolderHeld() async throws {
        let folder = try TemporaryFolder()
        let original = try folder.file("Open/original", size: 4000)
        try folder.file("Open/a.txt", size: 2000)
        try folder.file("Locked/old.png", size: 30000)
        try folder.file("Locked/old.mov", size: 2_000_000)
        #expect(link(original.path, folder.path + "/Locked/link") == 0)
        let target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "Fixture", firmlinks: .empty)
        let scanned = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag())
        // The folder changes, then closes: the scan keeps what it held, as a refresh that finds it closed does.
        try FileManager.default.removeItem(atPath: folder.path + "/Locked/old.png")
        try FileManager.default.removeItem(atPath: folder.path + "/Locked/old.mov")
        try folder.file("Locked/new.swift", size: 4000)
        try folder.file("Locked/Inner/new.zip", size: 1_200_000)
        // What root lists, read here while the folder is open, and sent as the helper sends it.
        let listed = ElevatedRead.read(ElevatedRead.Request(folders: [folder.path + "/Locked"]))
        let result = try JSONDecoder().decode(ElevatedRead.Result.self, from: JSONEncoder().encode(listed))
        var tree = scanned.tree
        try tree.setUnreadable(.needsAdministrator, at: #require(tree.index(ofPath: folder.path + "/Locked")))
        let read = DiskAnalyzerModel.adding(
            result, folders: [folder.path + "/Locked"], to: tree, summary: scanned.summary, volume: nil
        )
        let fresh = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag()).summary
        #expect(scanned.summary.categories.count(of: .image) == 1)
        #expect(read.summary.categories == fresh.categories)
        #expect(read.summary.categories.count(of: .image) == 0)
        #expect(read.summary.categories.count(of: .video) == 0)
        #expect(read.summary.categories.count(of: .archive) == 1)
        #expect(read.summary.categories.count(of: .other) == 2)
        #expect(read.summary.duplicateLinks == fresh.duplicateLinks)
        #expect(read.summary.files == fresh.files)
    }

    /// What root reads replaces what the folder held in the files only in the cloud and the entries with errors too, below
    /// it as well, as a fresh scan of the same files counts them. A test cannot make either on disk, so the folders are in
    /// memory.
    @Test func whatWasReadReplacesTheFilesOnlyInTheCloudAndTheFailedEntries() throws {
        var listings: [String: [DirectoryEntry]] = [
            "": [Fixtures.entry("Open", .directory), Fixtures.entry("Locked", .directory)],
            "Open": [Fixtures.cloudFile("song.m4a", content: 6_000_000), Fixtures.failedEntry("broken")],
            "Locked": [
                Fixtures.cloudFile("old.mov", content: 800_000_000),
                Fixtures.cloudFile("old.pdf", content: 90000),
                Fixtures.failedEntry("gone"),
            ],
        ]
        let scanned = Fixtures.scan(listings)
        // The folder changes, then closes: the scan keeps what it held, as a refresh that finds it closed does.
        var tree = scanned.tree
        try tree.setUnreadable(.needsAdministrator, at: #require(Fixtures.index("Locked", in: tree)))
        listings["Locked"] = [Fixtures.entry("Inner", .directory), Fixtures.cloudFile("new.pdf", content: 70000)]
        listings["Locked/Inner"] = [
            Fixtures.cloudFile("deep.mov", content: 5_000_000),
            Fixtures.failedEntry("first"),
            Fixtures.failedEntry("second"),
        ]
        // What root lists, digested as the listing mode digests it.
        let result = ElevatedRead.Result(listings: ["Locked", "Locked/Inner"].map { relative in
            let path = "/Root/" + relative
            return ElevatedRead.Listing(path: path, digest: Fixtures.digest(listings[relative] ?? [], parentPath: path, countsLinks: false))
        })
        let read = DiskAnalyzerModel.adding(result, folders: ["/Root/Locked"], to: tree, summary: scanned.summary, volume: nil)
        let fresh = Fixtures.scan(listings).summary
        #expect(scanned.summary.cloudOnlyFiles == 3)
        #expect(read.summary.cloudOnlyFiles == fresh.cloudOnlyFiles)
        #expect(read.summary.cloudOnlyBytes == fresh.cloudOnlyBytes)
        #expect(read.summary.entryErrors == fresh.entryErrors)
        #expect(read.summary.files == fresh.files)
    }

    /// A folder taken out of the scan since, or no longer waiting for an administrator, is left alone.
    @Test func onlyFoldersStillWaitingForAnAdministratorTakeWhatWasRead() throws {
        var tree = Fixtures.tree(["Open/": 0])
        let open = try #require(Fixtures.index("Open", in: tree))
        var digest = DirectoryDigest()
        digest.items = [Item(name: "x.bin", kind: .file, size: 2_000_000, logicalSize: 2_000_000)]
        let result = ElevatedRead.Result(listings: [ElevatedRead.Listing(path: "/Root/Open", digest: digest)])
        var summary = ScanSummary()
        let dirty = ElevatedRead.apply(result, folders: ["/Root/Open", "/Root/Gone"], to: &tree, summary: &summary)
        #expect(dirty.isEmpty)
        #expect(tree.children(of: open).isEmpty)
    }
}
