import Darwin
@testable import DiskAnalyzer
import Foundation
import Testing

/// The helpers that read the disk, each on a folder the test creates: a home folder of its own for the space hogs and
/// cloud folders, files to hash for the duplicates.
struct SystemHelperTests {
    @Test func spaceHogsAreMeasuredInAHomeFolderOfTheTestsOwn() async throws {
        let home = try TemporaryFolder()
        try home.file("Library/Caches/com.example.app/blob.bin", size: 2_000_000)
        try home.file("Library/Caches/Other/data.bin", size: 1_000_000)
        try home.file("Downloads/Installer.dmg", size: 3_000_000)
        try home.file("Downloads/Notes.txt", size: 100)
        let catalog = Dictionary(uniqueKeysWithValues: SpaceHogCatalog.all.map { ($0.id, $0) })
        let caches = try await SpaceHogMeter.measure(#require(catalog["caches"]), home: home.path, tree: nil)
        #expect(caches.bytes >= 3_000_000)
        #expect(caches.items.map { ($0 as NSString).lastPathComponent } == ["Other", "com.example.app"])
        let installers = try await SpaceHogMeter.measure(#require(catalog["installers"]), home: home.path, tree: nil)
        #expect(installers.items.map { ($0 as NSString).lastPathComponent } == ["Installer.dmg"])
        let logs = try await SpaceHogMeter.measure(#require(catalog["logs"]), home: home.path, tree: nil)
        #expect(logs == .none)
    }

    @Test func aFolderThatCannotBeReadSaysSo() async throws {
        let home = try TemporaryFolder()
        let logs = try home.folder("Library/Logs")
        #expect(chmod(logs.path, 0) == 0)
        defer { chmod(logs.path, 0o755) }
        let hog = try #require(SpaceHogCatalog.all.first { $0.id == "logs" })
        #expect(await SpaceHogMeter.measure(hog, home: home.path, tree: nil) == .unreadable)
    }

    @Test func foldersByNameCountTheOutermostOnly() async throws {
        let tree = Fixtures.tree([
            "a/node_modules/x/index.js": 2_000_000,
            "a/node_modules/y/node_modules/z.js": 1_000_000,
            "b/node_modules/w.js": 3_000_000,
        ])
        let hog = try #require(SpaceHogCatalog.all.first { $0.id == "nodeModules" })
        let found = await SpaceHogMeter.measure(hog, home: "/nowhere", tree: tree)
        #expect(found.bytes == 6_000_000)
        #expect(found.items.sorted() == ["/Root/a/node_modules", "/Root/b/node_modules"])
    }

    @Test func cloudFoldersAreFoundByName() throws {
        let home = try TemporaryFolder()
        try home.folder("Library/Mobile Documents/com~apple~CloudDocs")
        try home.folder("Library/CloudStorage/GoogleDrive-me@example.com")
        try home.folder("Library/CloudStorage/Dropbox")
        try home.file("Library/CloudStorage/.DS_Store", size: 10)
        let locations = CloudLocator.locations(home: home.path)
        #expect(locations.map(\.provider) == [.iCloud, .dropbox, .googleDrive])
        #expect(CloudLocator.locations(home: home.path + "/missing").isEmpty)
    }

    @Test func identicalFilesHashTheSameAndDifferentEndsDoNot() throws {
        let folder = try TemporaryFolder()
        let one = try folder.file("one.bin", size: 300_000, byte: 7)
        let two = try folder.file("two.bin", size: 300_000, byte: 7)
        var bytes = [UInt8](repeating: 7, count: 300_000)
        bytes[299_999] = 8
        let three = folder.url.appending(path: "three.bin")
        try Data(bytes).write(to: three)
        #expect(FileHasher.edges(of: one.path, size: 300_000) == FileHasher.edges(of: two.path, size: 300_000))
        #expect(FileHasher.edges(of: one.path, size: 300_000) != FileHasher.edges(of: three.path, size: 300_000))
        let flag = CancellationFlag()
        var read = 0
        let full = FileHasher.full(of: one.path, cancellation: flag) { read += $0 }
        #expect(full?.count == 64)
        #expect(read == 300_000)
        #expect(full == FileHasher.full(of: two.path, cancellation: flag) { _ in })
        #expect(FileHasher.edges(of: folder.path + "/missing", size: 1) == nil)
    }

    @Test func theDuplicateFinderGroupsCopiesOfAScan() async throws {
        let folder = try TemporaryFolder()
        try folder.file("a/movie.mov", size: 2_000_000, byte: 1)
        try folder.file("b/movie copy.mov", size: 2_000_000, byte: 1)
        try folder.file("c/other.mov", size: 2_000_000, byte: 2)
        try folder.file("d/single.bin", size: 3_000_000, byte: 3)
        let target = ScanTarget(requestedPath: folder.path, scanPath: folder.path, displayName: "Fixture", firmlinks: .empty)
        let outcome = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag())
        let candidates = DuplicateFinder.candidates(in: outcome.tree, under: ScanTree.rootIndex, minimumSize: 1_000_000)
        #expect(candidates.count == 4)
        let groups = await DuplicateFinder.find(candidates, minimumSize: 1_000_000, cancellation: CancellationFlag()) { _ in }
        #expect(groups.count == 1)
        let names = groups.first.map { $0.files.map { outcome.tree.name(of: $0) }.sorted() }
        #expect(names == ["movie copy.mov", "movie.mov"])
        #expect((groups.first?.reclaimable ?? 0) >= 2_000_000)
    }

    @Test func clonesAreToldApartFromCopies() throws {
        let folder = try TemporaryFolder()
        let original = try folder.file("original.bin", size: 2_000_000)
        let clone = folder.url.appending(path: "clone.bin")
        #expect(clonefile(original.path, clone.path, 0) == 0)
        let copy = try folder.file("copy.bin", size: 2_000_000)
        let originalFacts = try #require(CloneFacts.of(original.path))
        let cloneFacts = try #require(CloneFacts.of(clone.path))
        #expect(originalFacts.cloneID == cloneFacts.cloneID)
        #expect(cloneFacts.sharesAllBlocks)
        #expect(cloneFacts.privateSize == 0)
        #expect(CloneFacts.of(copy.path)?.cloneID != originalFacts.cloneID)
        #expect((CloneFacts.of(copy.path)?.privateSize ?? 0) > 0)
    }

    @Test func itemsAreCountedWithoutFollowingLinks() throws {
        let folder = try TemporaryFolder()
        try folder.file("set/a.bin", size: 1000)
        try folder.file("set/b/c.bin", size: 2000)
        try FileManager.default.createSymbolicLink(atPath: folder.path + "/set/link", withDestinationPath: folder.path)
        let census = ItemCensus.of(folder.url.appending(path: "set"))
        #expect(census.files == 3)
        #expect(census.bytes >= 3000)
        #expect(ItemCensus.of(folder.url.appending(path: "nothing")) == ItemCensus())
    }

    @Test func onlyLocalBrowsableVolumesAreCrossed() {
        #expect(MountCheck.isCrossable(flags: UInt32(MNT_LOCAL)))
        #expect(!MountCheck.isCrossable(flags: UInt32(MNT_LOCAL) | UInt32(MNT_DONTBROWSE)))
        #expect(!MountCheck.isCrossable(flags: UInt32(MNT_LOCAL) | UInt32(MNT_AUTOMOUNTED)))
        #expect(!MountCheck.isCrossable(flags: 0))
    }
}
