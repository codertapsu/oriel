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
