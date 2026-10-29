@testable import DiskAnalyzer
import OrielCore
import Testing

@MainActor
struct DiskAnalyzerModuleTests {
    @Test func theModuleHasItsID() {
        #expect(DiskAnalyzerModule.id == .diskAnalyzer)
        #expect(DiskAnalyzerModule().displayName == "Disk Space Analyzer")
        #expect(DiskAnalyzerModule().settingsSymbol == "internaldrive")
    }

    /// The ids, routes and groups the brief gives; neither has a default shortcut, so none can collide.
    @Test func itOffersTheWindowAndAFolderScan() throws {
        let commands = DiskAnalyzerModule().commands
        #expect(commands.map(\.id) == ["openDiskAnalyzer", "scanFolderWithDiskAnalyzer"])
        let open = try #require(commands.first)
        #expect(open.title == "Disk Space Analyzer")
        #expect(open.route == "disk")
        #expect(open.group == .tools)
        #expect(open.showsInMenu)
        #expect(open.defaultShortcut == nil)
        #expect(open.shortcutKey.name == "shortcuts.openDiskAnalyzer")
        let scan = try #require(commands.last)
        #expect(scan.title == "Scan Folder…")
        #expect(scan.route == "disk/scan")
        #expect(scan.group == .tools)
        #expect(!scan.showsInMenu)
        #expect(scan.defaultShortcut == nil)
    }

    @Test func itAnswersTheDiskVerbs() {
        let verbs = DiskAnalyzerModule().ipcCommands
        #expect(verbs.map(\.verb) == ["disk.volumes", "disk.scan"])
        #expect(verbs.map(\.usage) == ["disk volumes [--json]", "disk scan <path> [--top <n>] [--json]"])
    }

    @Test func itNeedsNoPermissionAndHasASettingsPane() {
        let module = DiskAnalyzerModule()
        #expect(module.requiredPermissions.isEmpty)
        #expect(module.menuItems.isEmpty)
        #expect(module.settingsPane != nil)
    }

    @Test func activationOnlyRemembersTheContext() async throws {
        let module = DiskAnalyzerModule()
        let settings = try Fixtures.memorySettings()
        await module.activate(context: ModuleContext(
            services: ServiceContainer(keychain: KeychainStore(), permissions: Fixtures.NoPermissions()),
            settings: settings,
            log: Log.logger("test")
        ))
        #expect(module.isActive)
        #expect(!module.isWindowOpen, "nothing opens until asked")
        await module.deactivate()
        #expect(!module.isActive)
    }
}
