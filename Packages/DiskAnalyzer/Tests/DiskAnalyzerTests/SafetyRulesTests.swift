@testable import DiskAnalyzer
import Testing

/// What Oriel refuses to remove or move, whatever is selected.
struct SafetyRulesTests {
    private let rules = SafetyRules(
        home: "/Users/me",
        volumeRoots: ["/", "/Volumes/Backup", "/System/Volumes/Data"],
        appBundle: "/Applications/Oriel.app",
        firmlinks: FirmlinkMap(parsing: "/Users\tUsers\n/Applications\tApplications\n/Library\tLibrary\n/private\tprivate\n")
    )

    @Test(arguments: [
        ("/", SafetyRules.Refusal.volumeRoot),
        ("/Volumes/Backup", .volumeRoot),
        ("/Volumes/Backup/", .volumeRoot),
        ("/System", .system),
        ("/System/Library/Frameworks/AppKit.framework", .system),
        ("/usr/bin/swift", .system),
        ("/usr/local", .system),
        ("/bin/zsh", .system),
        ("/private/var/folders/xy/cache", .system),
        ("/tmp", .system),
        ("/Library", .system),
        ("/Library/Application Support", .system),
        ("/Applications", .system),
        ("/Applications/Utilities", .system),
        ("/Users", .system),
        ("/Users/Shared", .userFolder),
        ("/Users/someone", .userFolder),
        ("/Users/me", .homeFolder),
        ("~", .homeFolder),
        ("/Users/me/Documents", .homeTopLevel),
        ("~/Library", .homeTopLevel),
        ("~/.Trash", .homeTopLevel),
        ("/Users/me/Library/Caches", .libraryFolder),
        ("/Users/me/Library/Containers", .libraryFolder),
        ("/Users/me/Library/Mobile Documents/com~apple~CloudDocs", .cloudRoot),
        ("/Users/me/Library/CloudStorage/GoogleDrive-me@example.com", .cloudRoot),
        ("/Users/me/Applications/Tool.app/Contents/MacOS/Tool", .insidePackage("Tool.app")),
        ("/Users/me/Pictures/Photos Library.photoslibrary/originals/A/1.heic", .insidePackage("Photos Library.photoslibrary")),
        ("/Applications/Oriel.app", .oriel),
        ("/System/Volumes/Data/Users/me", .homeFolder),
        ("/System/Volumes/Data/.Spotlight-V100", .system),
        ("/.file", .system),
        ("/.VolumeIcon.icns", .system),
        ("/pkg", .system),
        ("/System/Volumes/VM/sleepimage", .system),
        ("/System/Volumes/Preboot/Cryptexes", .system),
        ("/Users/me/Documents/../Desktop", .homeTopLevel),
    ])
    func refuses(_ path: String, _ refusal: SafetyRules.Refusal) {
        #expect(rules.refusal(for: path, isFolder: true) == refusal)
    }

    @Test(arguments: [
        "/Users/me/Downloads/Xcode_27.xip",
        "/Users/me/Documents/Taxes",
        "/Users/me/Library/Caches/com.example.app",
        "/Users/me/Library/Developer/Xcode/DerivedData/App-abc",
        "/Users/me/Library/Mobile Documents/com~apple~CloudDocs/Old Projects",
        "/Users/me/Pictures/Photos Library.photoslibrary",
        "/Applications/Xcode.app",
        "/usr/local/Cellar/node",
        "/private/tmp/big.log",
        "/Volumes/Backup/Old",
        "/Library/Caches/com.example",
        "/System/Volumes/Data/Users/me/Movies/clip.mov",
    ])
    func allows(_ path: String) {
        #expect(rules.refusal(for: path, isFolder: true) == nil)
    }

    @Test func theUsersTemporaryFolderHoldsTheirFiles() {
        let rules = SafetyRules(home: "/Users/me", volumeRoots: ["/"], appBundle: nil, temporaryFolder: "/var/folders/ab/cd/T/")
        #expect(rules.refusal(for: "/var/folders/ab/cd/T/huge.log", isFolder: false) == nil)
        #expect(rules.refusal(for: "/private/var/folders/ab/cd/T/build", isFolder: true) == nil)
        #expect(rules.refusal(for: "/var/folders/ab/cd/T", isFolder: true) == .system)
        #expect(rules.refusal(for: "/var/folders/ab/cd/C/com.apple.cache", isFolder: true) == .system)
    }

    @Test func aFileDirectlyInTheHomeFolderMayGoButAFolderMayNot() {
        #expect(rules.refusal(for: "/Users/me/big.iso", isFolder: false) == nil)
        #expect(rules.refusal(for: "/Users/me/Projects", isFolder: true) == .homeTopLevel)
    }

    @Test func anAppInApplicationsThatPointsIntoMacOSIsRefused() {
        let safari = rules.refusal(
            for: "/Applications/Safari.app", isFolder: false, symlinkDestination: "../System/Cryptexes/App/System/Applications/Safari.app"
        )
        #expect(safari == .systemApp)
        let alias = rules.refusal(for: "/Applications/Tool.app", isFolder: false, symlinkDestination: "/Users/me/Apps/Tool.app")
        #expect(alias == nil)
    }

    @Test func everyRefusalExplainsItself() {
        let refusals: [SafetyRules.Refusal] = [
            .volumeRoot, .system, .systemApp, .homeFolder, .homeTopLevel, .userFolder, .libraryFolder, .cloudRoot,
            .insidePackage("X.app"), .oriel,
        ]
        for refusal in refusals {
            #expect(refusal.message.hasSuffix("."))
        }
    }
}
