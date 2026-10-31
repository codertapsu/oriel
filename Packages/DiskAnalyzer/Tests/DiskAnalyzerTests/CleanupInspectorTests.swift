@testable import DiskAnalyzer
import Foundation
import Testing

/// What Clean Up reads from a real folder (PLAN §7.10 item 19): the scan's facts, the folder's names and tags, and the
/// processes using it. Everything happens in a temporary folder of the test's own.
struct CleanupInspectorTests {
    private func scan(_ folder: TemporaryFolder, options: ScanOptions = ScanOptions()) async -> ScanTree {
        let target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "", firmlinks: .empty)
        return await ScanEngine.scan(target, options: options, cancellation: CancellationFlag()).tree
    }

    @Test func theScanSaysWhatIsInsideAndWhereTheCachesAre() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        try folder.file("App/Cache/data_1", size: 3_000_000)
        try folder.file("App/Cache/Nested/Cache/data_2", size: 1_000_000)
        try folder.file("App/photo.jpg", size: 2_000_000)
        try folder.file("Project/.git/objects/pack.pack", size: 1_500_000)
        try folder.file("notes.txt", size: 10)
        let tree = await scan(folder)
        var facts = CleanupFacts(path: folder.path, home: "/Users/nobody", bytes: 0, fileCount: 0, folderCount: 0, children: [])
        CleanupInspector.addTreeFacts(&facts, node: ScanTree.rootIndex, tree: tree)
        #expect(facts.children.map(\.name) == ["App", "Project"])
        #expect(facts.children.allSatisfy { $0.lastUsed != nil })
        // The outermost cache only.
        #expect(facts.cacheFolders.map(\.path) == [folder.path + "/App/Cache"])
        #expect(facts.repositories == 1)
        #expect((facts.categories[.image] ?? 0) > 0)
    }

    @Test func theFolderSaysItIsACache() throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let cache = try folder.folder("tool-cache")
        try Data("Signature: 8a477f597d28d172789f06886806bc55\n# This file is a cache directory tag.\n".utf8)
            .write(to: cache.appending(path: "CACHEDIR.TAG"))
        try folder.file("tool-cache/blob", size: 100)
        try folder.file("package.json", size: 10)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = cache
        try url.setResourceValues(values)
        var facts = CleanupFacts(path: cache.path, home: "/Users/nobody", bytes: 0, fileCount: 0, folderCount: 0, children: [])
        CleanupInspector.addFolderFacts(&facts)
        #expect(facts.names == ["CACHEDIR.TAG", "blob"])
        #expect(facts.siblingNames.contains("package.json"))
        #expect(facts.isTaggedCache && facts.isExcludedFromBackup && facts.isRemovable)
        try Data("Signature: something else".utf8).write(to: cache.appending(path: "CACHEDIR.TAG"))
        CleanupInspector.addFolderFacts(&facts)
        #expect(!facts.isTaggedCache)
    }

    @Test func aProcessWithAFileOpenInsideUsesTheFolder() throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let file = try folder.file("Busy/data.bin", size: 1000)
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        // macOS reports /private/var/…; Clean Up asks with the spelling the window shows.
        let uses = FolderUsers.uses(of: folder.path)
        let own = try #require(uses.first { $0.pid == getpid() })
        #expect(own.paths.contains(folder.path + "/Busy/data.bin"))
        #expect(FolderUsers.uses(of: folder.path, excluding: [getpid()]).allSatisfy { $0.pid != getpid() })
    }

    @Test func aFolderIsSpelledAsMacOSMaySpellIt() {
        #expect(FolderUsers.spellings(of: "/Users/me/x/") == ["/Users/me/x", "/System/Volumes/Data/Users/me/x"])
        #expect(FolderUsers.spellings(of: "/var/folders/ab").contains("/private/var/folders/ab"))
        #expect(FolderUsers.respelled(
            "/private/var/folders/ab/c",
            from: FolderUsers.spellings(of: "/var/folders/ab"),
            to: "/var/folders/ab"
        )
            == "/var/folders/ab/c")
        #expect(FolderUsers.respelled("/var/folders/abc", from: ["/var/folders/ab"], to: "/var/folders/ab") == nil)
    }

    @Test func appsAreNamedByBundleIDOrByName() {
        #expect(CleanupApps.looksLikeBundleID("com.spotify.client"))
        #expect(CleanupApps.looksLikeBundleID("com.example.App.Share-Extension"))
        #expect(!CleanupApps.looksLikeBundleID("9.1.0"))
        #expect(!CleanupApps.looksLikeBundleID("Google"))
    }

    @Test func foldersOfCodeHoldNoCaches() async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        try folder.file("node_modules/webpack/lib/cache/index.js", size: 1000)
        try folder.file("Sources/App/Cache/Store.swift", size: 1000)
        try folder.file("App/Cache/data", size: 1000)
        let tree = await scan(folder)
        var facts = CleanupFacts(path: folder.path, home: "/Users/nobody", bytes: 0, fileCount: 0, folderCount: 0, children: [])
        CleanupInspector.addTreeFacts(&facts, node: ScanTree.rootIndex, tree: tree)
        #expect(facts.cacheFolders.map(\.path) == [folder.path + "/App/Cache"])
    }

    /// A worktree's `.git` is a file; a scan without hidden files lists no `.git` at all.
    @Test(arguments: [true, false])
    func repositoriesAreFoundInWorktreesAndWithoutHiddenFiles(_ hidden: Bool) async throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        try folder.file("Project/.git/HEAD", size: 10)
        try folder.file("Project/main.swift", size: 10)
        try folder.file("Worktree/.git", size: 10)
        try folder.file("Worktree/main.swift", size: 10)
        var options = ScanOptions()
        options.includesHiddenFiles = hidden
        var facts = CleanupFacts(path: folder.path, home: "/Users/nobody", bytes: 0, fileCount: 0, folderCount: 0, children: [])
        let tree = await scan(folder, options: options)
        CleanupInspector.addTreeFacts(&facts, node: ScanTree.rootIndex, tree: tree)
        CleanupInspector.addFolderFacts(&facts)
        #expect(facts.repositories == 2)
    }

    @Test func everyFileAProcessHasOpenCounts() throws {
        var limit = rlimit()
        getrlimit(RLIMIT_NOFILE, &limit)
        if limit.rlim_cur < 1024 {
            limit.rlim_cur = min(1024, limit.rlim_max)
            setrlimit(RLIMIT_NOFILE, &limit)
        }
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        var handles: [FileHandle] = []
        defer { handles.forEach { try? $0.close() } }
        for index in 0 ..< 205 {
            try handles.append(FileHandle(forReadingFrom: folder.file("A/\(index)", size: 1)))
        }
        try handles.append(FileHandle(forReadingFrom: folder.file("B/last", size: 1)))
        let own = try #require(FolderUsers.uses(of: folder.path).first { $0.pid == getpid() })
        #expect(own.paths.contains(folder.path + "/B/last"))
        #expect(own.paths.count >= 206)
    }

    @Test func aFolderReachedThroughALinkIsSeenWhereItIs() throws {
        let folder = try TemporaryFolder()
        defer { folder.remove() }
        let file = try folder.file("Real/data.bin", size: 100)
        let link = folder.path + "/Link"
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: folder.path + "/Real")
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        let own = try #require(FolderUsers.uses(of: link).first { $0.pid == getpid() })
        #expect(own.paths.contains(link + "/data.bin"))
    }
}
