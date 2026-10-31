@testable import DiskAnalyzer
import Testing

/// Full Disk Access as the scan shows it (never probed, CLAUDE.md rule 8): a scan that read Safari's, Mail's or
/// Messages' folder has it, so the folders macOS still refuses are closed to every app; one macOS refused them to has
/// not; one that held none of them cannot tell.
struct FullDiskAccessEvidenceTests {
    private let home = "/Users/me"

    @Test func aReadSafariFolderMeansFullDiskAccess() throws {
        var tree = Fixtures.tree(["Library/Safari/History.db": 1000, "Library/Biome/": 0], rootPath: home)
        let biome = try #require(Fixtures.index("Library/Biome", in: tree))
        tree.setUnreadable(.protectedByMacOS, at: biome)
        #expect(FullDiskAccessEvidence.isGranted(in: tree, home: home) == true)
    }

    @Test func aRefusedMailFolderMeansNone() throws {
        var tree = Fixtures.tree(["Library/Mail/": 0, "Documents/notes.txt": 10], rootPath: home)
        let mail = try #require(Fixtures.index("Library/Mail", in: tree))
        tree.setUnreadable(.protectedByMacOS, at: mail)
        #expect(FullDiskAccessEvidence.isGranted(in: tree, home: home) == false)
    }

    @Test func aScanWithoutThemCannotTell() {
        let tree = Fixtures.tree(["Documents/notes.txt": 10], rootPath: home)
        #expect(FullDiskAccessEvidence.isGranted(in: tree, home: home) == nil)
    }
}
