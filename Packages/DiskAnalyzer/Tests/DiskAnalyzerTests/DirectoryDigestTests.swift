@testable import DiskAnalyzer
import Testing

/// The counting rules for one directory: what is kept, what is summed, what is entered.
struct DirectoryDigestTests {
    @Test func keepsLargeFilesAndSumsTheSmallerOnesExactly() {
        let digest = Fixtures.digest([
            Fixtures.entry("movie.mov", size: 5_000_000),
            Fixtures.entry("a.txt", size: 4096),
            Fixtures.entry("b.txt", size: 8192),
            Fixtures.entry("exactly.bin", size: 1_000_000),
        ])
        #expect(digest.items.map(\.name).sorted() == ["exactly.bin", "movie.mov"])
        #expect(digest.small.count == 2)
        #expect(digest.small.size == 12288)
        #expect(digest.categoryTotals.count(of: .video) == 1)
        #expect(digest.categoryTotals.bytes(of: .document) == 12288)
        #expect(digest.categoryTotals.totalBytes == 5_000_000 + 12288 + 1_000_000)
    }

    @Test func theThresholdIsASetting() {
        var options = ScanOptions()
        options.smallFileThreshold = 10000
        let digest = Fixtures.digest([Fixtures.entry("a.txt", size: 4096), Fixtures.entry("b.txt", size: 20000)], options: options)
        #expect(digest.items.map(\.name) == ["b.txt"])
        #expect(digest.small.count == 1)
    }

    /// Which link of a file carries its size depends on what the rest of the scan counted, so a listing leaves its files
    /// with several links to be counted, with what they are.
    @Test func filesWithSeveralLinksWaitToBeCounted() {
        let digest = Fixtures.digest(
            [Fixtures.entry("a.bin", size: 3_000_000, inode: 42, links: 2), Fixtures.entry("b.txt", size: 10, inode: 43, links: 3)],
            countsLinks: false
        )
        #expect(digest.items.isEmpty)
        #expect(digest.small.count == 0)
        #expect(digest.categoryTotals.totalCount == 0)
        #expect(digest.links.map(\.file) == [.init(device: 1, inode: 42), .init(device: 1, inode: 43)])
        #expect(digest.links.map(\.isKept) == [true, false])
        #expect(digest.links.allSatisfy { $0.item.flags.contains(.hardLink) && $0.item.size > 0 })
    }

    @Test func aHardLinkedFileIsCountedOnce() {
        let digests = Fixtures.counted([
            Fixtures.digest([Fixtures.entry("a.bin", size: 3_000_000, inode: 42, links: 2)], countsLinks: false),
            Fixtures.digest([Fixtures.entry("b.bin", size: 3_000_000, inode: 42, links: 2)], countsLinks: false),
        ])
        let first = digests[0]
        let second = digests[1]
        #expect(first.items.first?.size == 3_000_000)
        #expect(first.items.first?.flags.contains(.hardLink) == true)
        #expect(second.items.isEmpty)
        #expect(second.small.count == 1)
        #expect(second.small.size == 0)
        #expect(second.duplicateLinks == 1)
        #expect(second.categoryTotals.totalCount == 1)
        #expect(second.categoryTotals.totalBytes == 0)
    }

    @Test func linksWithinOneFolderAreCountedOnceToo() {
        let digest = Fixtures.digest([
            Fixtures.entry("a.bin", size: 3_000_000, inode: 7, links: 2),
            Fixtures.entry("b.bin", size: 3_000_000, inode: 7, links: 2),
            Fixtures.entry("c.bin", size: 3_000_000, inode: 8, links: 1),
        ])
        #expect(digest.items.reduce(0) { $0 + $1.size } + digest.small.size == 6_000_000)
        #expect(digest.duplicateLinks == 1)
    }

    @Test func theSameInodeOnAnotherDeviceIsAnotherFile() {
        var other = Fixtures.entry("b.bin", size: 3_000_000, inode: 7, links: 2)
        other.device = 2
        let digest = Fixtures.digest([Fixtures.entry("a.bin", size: 3_000_000, inode: 7, links: 2), other])
        #expect(digest.duplicateLinks == 0)
    }

    @Test func symlinksAreCountedAsSmallItemsAndNeverEntered() {
        let digest = Fixtures.digest([Fixtures.entry("link", .symlink, size: 0)])
        #expect(digest.items.isEmpty)
        #expect(digest.small.count == 1)
    }

    @Test func foldersAreEnteredUnlessTheyAreSpecial() {
        var mount = Fixtures.entry("Backup", .directory)
        mount.isMountPoint = true
        var trigger = Fixtures.entry("home", .directory)
        trigger.isMountTrigger = true
        let firmlink = Fixtures.entry("Users", .directory, flags: DirectoryEntry.firmlinkFlag)
        let cloud = Fixtures.entry("Photos", .directory, flags: DirectoryEntry.datalessFlag)
        let digest = Fixtures.digest([Fixtures.entry("Projects", .directory), mount, trigger, firmlink, cloud])
        let byName = Dictionary(uniqueKeysWithValues: digest.items.map { ($0.name, $0) })
        #expect(byName["Projects"]?.descends == true)
        #expect(byName["Backup"]?.descends == false)
        #expect(byName["Backup"]?.flags.contains(.mountPoint) == true)
        #expect(byName["home"]?.descends == false)
        #expect(byName["Users"]?.flags.contains(.firmlink) == true)
        #expect(byName["Users"]?.descends == false)
        #expect(byName["Photos"]?.flags.contains(.cloudOnly) == true)
        #expect(byName["Photos"]?.descends == false)
    }

    @Test func otherVolumesAreEnteredOnlyWhenAllowedAndCrossable() {
        var mount = Fixtures.entry("Backup", .directory)
        mount.isMountPoint = true
        var options = ScanOptions()
        options.crossesVolumes = true
        let crossing = Fixtures.digest([mount], options: options) { $0 == "/Root/Backup" }
        #expect(crossing.items.first?.descends == true)
        #expect(crossing.items.first?.crossesVolume == true)
        let refused = Fixtures.digest([mount], options: options) { _ in false }
        #expect(refused.items.first?.descends == false)
        let notAllowed = Fixtures.digest([mount]) { _ in true }
        #expect(notAllowed.items.first?.descends == false)
    }

    @Test func excludedFoldersAreListedButNotEntered() {
        var options = ScanOptions()
        options.exclusions = ExclusionRules(["node_modules", "/Root/Archive"], home: "/Users/me")
        let digest = Fixtures.digest(
            [Fixtures.entry("node_modules", .directory), Fixtures.entry("Archive", .directory), Fixtures.entry("src", .directory)],
            options: options
        )
        let excluded = digest.items.filter { $0.flags.contains(.excluded) }.map(\.name).sorted()
        #expect(excluded == ["Archive", "node_modules"])
        #expect(digest.items.filter(\.descends).map(\.name) == ["src"])
    }

    @Test func hiddenItemsCanBeLeftOut() {
        let entries = [
            Fixtures.entry(".cache", .directory),
            Fixtures.entry(".DS_Store", size: 6148),
            Fixtures.entry("Flagged", .directory, flags: DirectoryEntry.hiddenFlag),
            Fixtures.entry("visible.txt", size: 10),
        ]
        let shown = Fixtures.digest(entries)
        #expect(shown.items.count == 2)
        #expect(shown.items.allSatisfy { $0.flags.contains(.hidden) })
        var options = ScanOptions()
        options.includesHiddenFiles = false
        let left = Fixtures.digest(entries, options: options)
        #expect(left.items.isEmpty)
        #expect(left.small.count == 1)
    }

    @Test func filesOnlyInTheCloudAreCountedByContentSize() {
        var evicted = Fixtures.entry("Lecture.mp4", size: 0, flags: DirectoryEntry.datalessFlag)
        evicted.logicalSize = 2_000_000_000
        let digest = Fixtures.digest([evicted])
        #expect(digest.cloudOnlyFiles == 1)
        #expect(digest.cloudOnlyBytes == 2_000_000_000)
        #expect(digest.items.first?.flags.contains(.cloudOnly) == true)
        #expect(digest.items.first?.size == 0)
    }

    @Test func filesInsideAPackageTakeItsCategory() {
        let app = Fixtures.digest([Fixtures.entry("Xcode.app", .directory)])
        #expect(app.items.first?.kind == .package)
        #expect(app.items.first?.inheritedCategory == .application)
        let inside = Fixtures.digest([Fixtures.entry("libLLVM.dylib", size: 90_000_000)], inherited: .application)
        #expect(inside.items.first?.category == .application)
        #expect(inside.categoryTotals.count(of: .application) == 1)
    }

    @Test func entriesWithErrorsAreLeftOutAndCounted() {
        var broken = Fixtures.entry("broken")
        broken.error = 5
        let digest = Fixtures.digest([broken, Fixtures.entry("ok.txt", size: 1)])
        #expect(digest.entryErrors == 1)
        #expect(digest.small.count == 1)
    }

    @Test func clonesAndPurgeableFilesAreMarked() {
        var clone = Fixtures.entry("clone.mov", size: 9_000_000)
        clone.extendedFlags = 0x41
        var purgeable = Fixtures.entry("cache.bin", size: 9_000_000)
        purgeable.extendedFlags = DirectoryEntry.isPurgeable
        let digest = Fixtures.digest([clone, purgeable])
        let byName = Dictionary(uniqueKeysWithValues: digest.items.map { ($0.name, $0.flags) })
        #expect(byName["clone.mov"]?.contains(.sharesBlocks) == true)
        #expect(byName["cache.bin"]?.contains(.purgeable) == true)
    }
}
