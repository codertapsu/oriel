@testable import DiskAnalyzer
import Foundation
import Testing

/// What Oriel reads from system tools and files, and how it quotes what it hands to them.
struct SystemTextTests {
    @Test func localSnapshotsAreReadFromTmutil() throws {
        let output = """
        Snapshots for disk /:
        com.apple.TimeMachine.2026-10-28-091756.local
        com.apple.TimeMachine.2026-10-29-101532.local
        """
        let snapshots = LocalSnapshotList.snapshots(fromList: output)
        #expect(snapshots.map(\.name) == ["com.apple.TimeMachine.2026-10-28-091756.local", "com.apple.TimeMachine.2026-10-29-101532.local"])
        let date = try #require(snapshots.first?.date)
        let parts = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        #expect([parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second] == [2026, 10, 28, 9, 17, 56])
    }

    @Test func noSnapshotsIsAnEmptyList() {
        #expect(LocalSnapshotList.snapshots(fromList: "Snapshots for disk /:\n").isEmpty)
        #expect(LocalSnapshotList.snapshots(fromList: "").isEmpty)
    }

    @Test func thinningReportsHowManyWentAway() {
        let output = "Thinned local snapshots:\n2026-10-28-091756\n2026-10-29-101532\n"
        #expect(LocalSnapshotList.thinnedCount(fromThin: output) == 2)
        #expect(LocalSnapshotList.thinnedCount(fromThin: "Thinned local snapshots:\n") == 0)
    }

    @Test func adminCommandsQuoteEveryArgument() {
        #expect(AdminCommand.shellQuote("/Volumes/My Disk") == "'/Volumes/My Disk'")
        #expect(AdminCommand.shellQuote("it's") == #"'it'\''s'"#)
        #expect(AdminCommand.shellCommand(["/usr/bin/tmutil", "thinlocalsnapshots", "/", "1000", "4"])
            == "'/usr/bin/tmutil' 'thinlocalsnapshots' '/' '1000' '4'")
        let script = AdminCommand.appleScript(for: ["/usr/bin/tmutil", "thinlocalsnapshots", "/Volumes/A \"B\" $C"], prompt: "Thin")
        let command = #"'/usr/bin/tmutil' 'thinlocalsnapshots' '/Volumes/A \"B\" $C'"#
        #expect(script == "do shell script \"\(command)\" with prompt \"Thin\" with administrator privileges")
    }

    @Test func appleScriptStringsEscapeBackslashesAndQuotes() {
        #expect(AdminCommand.appleScriptString(#"a\b"c"#) == #""a\\b\"c""#)
    }

    @Test func firmlinksAreParsedAndMappedBothWays() {
        let map = FirmlinkMap(parsing: "/Users\tUsers\n/usr/local\tusr/local\n/System/Library/Caches\tSystem/Library/Caches\nbad line\n")
        #expect(map.links.count == 3)
        #expect(map.visiblePath(for: "/System/Volumes/Data/Users/me/a.txt") == "/Users/me/a.txt")
        #expect(map.visiblePath(for: "/System/Volumes/Data/usr/local/bin") == "/usr/local/bin")
        #expect(map.visiblePath(for: "/System/Volumes/Data/.Spotlight-V100") == "/System/Volumes/Data/.Spotlight-V100")
        #expect(map.visiblePath(for: "/System/Volumes/Data/UsersExtra") == "/System/Volumes/Data/UsersExtra")
        #expect(map.dataPath(for: "/Users/me") == "/System/Volumes/Data/Users/me")
        #expect(map.dataPath(for: "/Volumes/USB") == "/Volumes/USB")
    }

    @Test func exclusionsArePathsOrNames() {
        let rules = ExclusionRules(
            ["~/Library/Caches", "node_modules", "  ", "/Volumes/Backup/"],
            home: "/Users/me",
            firmlinks: FirmlinkMap(parsing: "/Users\tUsers\n")
        )
        #expect(rules.excludes(path: "/Users/me/Library/Caches", name: "Caches"))
        #expect(rules.excludes(path: "/System/Volumes/Data/Users/me/Library/Caches", name: "Caches"))
        #expect(rules.excludes(path: "/anywhere/node_modules", name: "node_modules"))
        #expect(rules.excludes(path: "/Volumes/Backup", name: "Backup"))
        #expect(!rules.excludes(path: "/Users/me/Library", name: "Library"))
        #expect(!ExclusionRules().excludes(path: "/a", name: "a"))
        #expect(ExclusionRules().isEmpty)
    }

    @Test func pathsAreNormalizedWithoutTouchingTheDisk() {
        #expect(ExclusionRules.normalize("~/a/./b/../c/", home: "/Users/me") == "/Users/me/a/c")
        #expect(ExclusionRules.normalize("/private/tmp", home: "/Users/me") == "/private/tmp")
        #expect(ExclusionRules.normalize("//a//b", home: "/") == "/a/b")
        #expect(ExclusionRules.normalize("/..", home: "/") == "/")
    }

    static let cloudFolders: [(String, CloudLocation.Provider, String?)] = [
        ("GoogleDrive-me@example.com", .googleDrive, "me@example.com"),
        ("Dropbox", .dropbox, nil),
        ("OneDrive-Personal", .oneDrive, "Personal"),
        ("Box-Box", .box, "Box"),
        ("Nextcloud-server", .other, "server"),
    ]

    @Test(arguments: cloudFolders)
    func cloudFoldersNameTheirProvider(_ folder: String, _ provider: CloudLocation.Provider, _ account: String?) {
        let location = CloudLocation.fileProvider(folderName: folder, in: "/Users/me/Library/CloudStorage")
        #expect(location.provider == provider)
        #expect(location.account == account)
        #expect(location.path == "/Users/me/Library/CloudStorage/" + folder)
    }

    @Test func everyKnownProviderLinksToItsStoragePage() {
        for provider in CloudLocation.Provider.allCases where provider != .other {
            #expect(provider.storagePage != nil)
        }
        #expect(CloudLocation.Provider.other.storagePage == nil)
    }

    @Test(arguments: [
        ("clip.MOV", FileCategory.video), ("song.flac", .audio), ("IMG_1.HEIC", .image), ("report.pdf", .document),
        ("backup.tar", .archive), ("Xcode.xip", .archive), ("macOS.dmg", .diskImage), ("Tool.pkg", .application),
        ("main.swift", .code), ("README", .other), (".zshrc", .other), ("weird.qwertyuiop", .other),
    ])
    func filesAreSortedIntoCategories(_ name: String, _ category: FileCategory) {
        #expect(FileCategory.of(name: name) == category)
        var cache = FileCategoryCache()
        let cached = cache.category(of: name)
        #expect(cached == category)
    }

    @Test func packagesAreRecognized() {
        var cache = FileCategoryCache()
        let names = ["Xcode.app", "Photos Library.photoslibrary", "Report.pages", "Projects", "v1.2"]
        let packages = names.map { cache.isPackage($0) }
        #expect(packages == [true, true, true, false, false])
    }

    @Test func categoryTotalsMergeAndRank() {
        var totals = CategoryTotals()
        totals.add(.video, bytes: 500)
        totals.add(.image, bytes: 100, count: 3)
        var other = CategoryTotals()
        other.add(.video, bytes: 50)
        totals.merge(other)
        #expect(totals.count(of: .video) == 2)
        #expect(totals.bytes(of: .video) == 550)
        #expect(totals.totalCount == 5)
        #expect(totals.ranked == [.video, .image])
    }
}
