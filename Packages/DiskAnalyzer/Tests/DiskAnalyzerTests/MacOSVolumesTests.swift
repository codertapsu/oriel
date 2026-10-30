@testable import DiskAnalyzer
import Foundation
import Testing

/// macOS's own volumes counted file by file: read next to the data volume into a folder of their own, without what
/// their firmlinks lead to or the volumes mounted on them, kept out of the lists meant for removing things, and never
/// refreshed or offered for removal.
struct MacOSVolumesTests {
    private typealias Item = DirectoryDigest.Item

    @Test func firmlinksTriggersAndForeignVolumesAreLeftOutAndHelperVolumesEntered() {
        let firmlink = Fixtures.entry("Users", .directory, flags: DirectoryEntry.firmlinkFlag)
        var trigger = Fixtures.entry("home", .directory)
        trigger.isMountTrigger = true
        var data = Fixtures.entry("Data", .directory)
        data.isMountPoint = true
        var preboot = Fixtures.entry("Preboot", .directory)
        preboot.isMountPoint = true
        let library = Fixtures.entry("Library", .directory)
        let swap = Fixtures.entry("swapfile0", size: 2_000_000_000)
        var categories = FileCategoryCache()
        let digest = DirectoryDigest.make(
            entries: [firmlink, trigger, data, preboot, library, swap],
            parentPath: "/System/Volumes",
            inheritedCategory: nil,
            options: ScanOptions(),
            categories: &categories,
            isFirstLink: { _, _ in true },
            macOS: MacOSVolumes(helperMounts: ["/System/Volumes/Preboot"])
        )
        #expect(digest.items.map(\.name).sorted() == ["Library", "Preboot", "swapfile0"])
        let entered = digest.items.first { $0.name == "Preboot" }
        #expect(entered?.descends == true && entered?.crossesVolume == true)
        #expect(digest.items.allSatisfy { $0.flags.contains(.macOSVolume) })
    }

    /// Preboot's cryptexes are grafted in from disk images that are APFS clones of each other, so its files would count
    /// the same space more than once: it is one block of what it uses.
    @Test func prebootIsOneBlockAndTheOtherHelperVolumesAreRead() {
        let volumes = MacOSVolumes.startup(helperMounts: ["/System/Volumes/Preboot", "/System/Volumes/VM", "/System/Volumes/Update"])
        #expect(volumes.helperMounts == ["/System/Volumes/VM", "/System/Volumes/Update"])
        #expect(volumes.blockMounts == ["/System/Volumes/Preboot"])
        var preboot = Fixtures.entry("Preboot", .directory)
        preboot.isMountPoint = true
        #expect(!volumes.keeps(preboot, at: "/System/Volumes/Preboot"))
        #expect(!volumes.keeps(Fixtures.entry(".nofollow", .directory), at: "/.nofollow"))
        #expect(volumes.keeps(Fixtures.entry(".nofollow", .directory), at: "/usr/.nofollow"))
    }

    /// What `df` shows for a volume, not the whole container's use, which `statfs` gives every APFS volume.
    @Test func aVolumesOwnUseIsBelowItsContainers() throws {
        let system = try #require(VolumeService.spaceUsed("/"))
        let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        let containerUsed = try Int64(#require(values.volumeTotalCapacity)) - Int64(#require(values.volumeAvailableCapacity))
        #expect(system > 1_000_000_000)
        #expect(VolumeService.systemBytes() < containerUsed)
    }

    @Test func pathsBelowTheMacOSFolderStartAtTheSystemVolumeThroughEditsAndCompaction() throws {
        var tree = ScanTree(rootName: "Macintosh HD", rootPath: FirmlinkMap.dataVolume, firmlinks: FirmlinkMap(parsing: "/Users\tUsers\n"))
        let users = tree.append(Item(name: "Users", kind: .folder), to: ScanTree.rootIndex)
        let gone = tree.append(Item(name: "Gone", kind: .folder), to: ScanTree.rootIndex)
        let macOS = tree.appendAnchor(Item(name: "macOS", kind: .folder, flags: .macOSVolume), path: "/")
        let system = tree.append(Item(name: "System", kind: .folder, flags: .macOSVolume), to: macOS)
        tree.append(Item(name: "dyld", kind: .file, size: 4_000_000, logicalSize: 4_000_000, flags: .macOSVolume), to: system)
        tree.computeTotals()
        #expect(tree.path(of: macOS) == "/")
        #expect(tree.path(of: system) == "/System")
        #expect(tree.displayPath(of: users) == "/Users")
        #expect(tree.index(ofPath: "/System") == system)
        #expect(tree.index(ofPath: "/Users") == users)
        #expect(tree.hasMacOSVolumes)

        // A fresh listing of the data volume's top keeps the folder of macOS's volumes, which is read from elsewhere.
        var listing = DirectoryDigest()
        listing.items = [Item(name: "Users", kind: .folder)]
        _ = tree.replaceContents(of: ScanTree.rootIndex, with: listing)
        #expect(tree.children(of: ScanTree.rootIndex).contains(macOS))
        #expect(!tree.contains(gone))

        let compacted = tree.compacted()
        let moved = try #require(compacted.index(ofPath: "/System/dyld"))
        #expect(compacted.path(of: moved) == "/System/dyld")
        #expect(compacted.hasMacOSVolumes)
    }

    @Test func aScanReadsMacOSsVolumesIntoAFolderOfTheirOwn() async throws {
        let data = try TemporaryFolder()
        let movie = try data.file("Users/me/movie.mov", size: 3_000_000)
        let system = try TemporaryFolder()
        let dylib = try system.file("System/Library/big.dylib", size: 2_000_000)
        try system.file("usr/bin/tool", size: 1_500_000)
        var target = ScanTarget(requestedPath: data.path, scanPath: data.path, displayName: "Disk", firmlinks: .empty)
        target.macOSVolumes = MacOSVolumes(systemPath: system.path, helperMounts: [])
        let tree = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag()).tree

        let macOS = try #require(tree.children(of: ScanTree.rootIndex).first { tree.name(of: $0) == "macOS" })
        #expect(tree.path(of: macOS) == system.path)
        #expect(tree[macOS].flags.contains(.macOSVolume))
        let library = try #require(tree.index(ofPath: dylib.path))
        #expect(tree[library].flags.contains(.macOSVolume))
        #expect(tree.isAncestor(macOS, of: library))
        let film = try #require(tree.index(ofPath: movie.path))
        #expect(!tree[film].flags.contains(.macOSVolume))
        #expect(tree.root.fileCount == 3)
        #expect(tree[macOS].fileCount == 2)
        #expect(tree.hasMacOSVolumes)
    }

    @Test func aBlockVolumeIsCountedByTheSpaceItUses() async throws {
        let data = try TemporaryFolder()
        let system = try TemporaryFolder()
        try system.file("System/a.bin", size: 2_000_000)
        var target = ScanTarget(requestedPath: data.path, scanPath: data.path, displayName: "Disk", firmlinks: .empty)
        target.macOSVolumes = MacOSVolumes(systemPath: system.path, helperMounts: [], blockMounts: [data.path])
        let tree = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag()).tree
        let macOS = try #require(tree.children(of: ScanTree.rootIndex).first { tree.name(of: $0) == "macOS" })
        let block = try #require(tree.children(of: macOS).first { tree[$0].kind == .system })
        #expect(tree.name(of: block) == data.url.lastPathComponent)
        #expect(tree[block].size > 0)
        #expect(tree[macOS].size > tree[block].size)
    }

    @Test func aRefreshLeavesMacOSsVolumesAndWhatWasReadAsAdministratorAlone() async throws {
        let system = try TemporaryFolder()
        try system.file("System/a.bin", size: 2_000_000)
        var target = ScanTarget(requestedPath: system.path, scanPath: system.path, displayName: "Disk", firmlinks: .empty)
        target.macOSVolumes = MacOSVolumes(systemPath: system.path, helperMounts: [])
        let tree = await ScanEngine.scan(target, options: ScanOptions(), cancellation: CancellationFlag()).tree
        let macOS = try #require(tree.children(of: ScanTree.rootIndex).first { tree.name(of: $0) == "macOS" })
        try system.file("System/b.bin", size: 2_000_000)
        let refreshed = await ScanEngine.refresh(
            tree, folders: [macOS], recursive: [macOS], options: ScanOptions(), cancellation: CancellationFlag()
        ).tree
        #expect(refreshed[macOS].fileCount == 1)
    }

    @Test func biggestAndOldFilesLeaveMacOSsFilesOutUnlessItsFolderIsShown() {
        var tree = Fixtures.tree(["Users/movie.mov": 3_000_000])
        let macOS = tree.appendAnchor(Item(name: "macOS", kind: .folder, flags: .macOSVolume), path: "/")
        tree.append(Item(name: "sleepimage", kind: .file, size: 9_000_000, logicalSize: 9_000_000, flags: .macOSVolume), to: macOS)
        tree.computeTotals()
        var query = FileQuery(
            mode: .biggest, version: 0, folder: ScanTree.rootIndex, filter: FileFilter(), sort: FileSort(), search: "", lastOpenedCount: 0
        )
        #expect(query.run(in: tree, lastOpened: [:]).rows.map(tree.name(of:)) == ["movie.mov"])
        query.mode = .old
        #expect(query.run(in: tree, lastOpened: [:]).rows.map(tree.name(of:)) == ["movie.mov"])
        query.mode = .biggest
        query.folder = macOS
        #expect(query.run(in: tree, lastOpened: [:]).rows.map(tree.name(of:)) == ["sleepimage"])
        query.folder = ScanTree.rootIndex
        query.mode = .search
        query.search = "sleep"
        #expect(query.run(in: tree, lastOpened: [:]).rows.map(tree.name(of:)) == ["sleepimage"])
    }

    @Test func duplicatesCompareNeitherMacOSsFilesNorWhatOnlyAnAdministratorCanOpen() {
        var tree = Fixtures.tree(["Users/a.mov": 3_000_000, "Users/b.mov": 3_000_000])
        let macOS = tree.appendAnchor(Item(name: "macOS", kind: .folder, flags: .macOSVolume), path: "/")
        tree.append(Item(name: "a.mov", kind: .file, size: 3_000_000, logicalSize: 3_000_000, flags: .macOSVolume), to: macOS)
        let root = tree.append(Item(name: "root", kind: .folder, flags: .readAsAdministrator), to: ScanTree.rootIndex)
        tree.append(Item(name: "a.mov", kind: .file, size: 3_000_000, logicalSize: 3_000_000, flags: .readAsAdministrator), to: root)
        let names = DuplicateFinder.candidates(in: tree, under: ScanTree.rootIndex, minimumSize: 1).map { tree.path(of: $0.node) }
        #expect(names.sorted() == ["/Root/Users/a.mov", "/Root/Users/b.mov"])
    }
}
