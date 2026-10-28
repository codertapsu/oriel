import Foundation
import OrielCore
import Testing
@testable import WindowSwitcher

/// `oriel windows …` (PLAN §7.1.8) through the module's IPC handlers, against the fake source. The module is
/// never activated here, so no event tap or observer exists.
@MainActor
struct WindowCommandsTests {
    private func module() async -> (WindowSwitcherModule, FakeWindowSource) {
        let source = await Fixture.source()
        let module = WindowSwitcherModule(
            sourceFactory: { _ in source },
            hotKeys: FakeHotKeys(),
            hotKeyGuard: SymbolicHotKeyGuard(installsExitHandlers: false),
            isTrusted: { false }
        )
        return (module, source)
    }

    private typealias Options = [String: String]

    private func run(
        _ verb: String,
        _ arguments: [String] = [],
        _ options: Options = [:],
        on module: WindowSwitcherModule
    ) async throws -> IPCResponse {
        let handler = try #require(module.ipcCommands.first { $0.verb == verb })
        return await handler.handle(IPCRequest(verb: verb, arguments: arguments, options: options))
    }

    @Test func theModuleDescribesItself() async {
        let (module, _) = await module()
        #expect(WindowSwitcherModule.id == .windowSwitcher)
        #expect(module.displayName == "Window Switcher")
        #expect(module.requiredPermissions == [.accessibility])
        #expect(module.menuItems.isEmpty)
        #expect(module.settingsPane != nil)
        let verbs = Set(module.ipcCommands.map(\.verb))
        #expect(verbs.isSuperset(of: ["windows.list", "windows.focus", "windows.close", "windows.minimize"]))
        #expect(verbs.contains("debug.open-switcher"))
    }

    @Test func listPrintsJSONWindowInfo() async throws {
        let (module, _) = await module()
        let response = try await run("windows.list", [], ["json": "true"], on: module)
        #expect(response.status == 0)
        let windows = try JSONDecoder().decode([WindowInfo].self, from: Data(response.output.utf8))
        #expect(windows.map(\.id) == [10, 50, 11, 14, 20, 21])
        #expect(windows.first { $0.id == 11 }?.spaceIndex == 2)
    }

    @Test func listFiltersBySpaceAndApp() async throws {
        let (module, _) = await module()
        let current = try await run("windows.list", [], ["json": "true", "space": "current"], on: module)
        let currentIDs = try JSONDecoder().decode([WindowInfo].self, from: Data(current.output.utf8)).map(\.id)
        #expect(currentIDs == [10, 50, 20, 21])
        let notes = try await run("windows.list", [], ["json": "true", "app": "COM.APPLE.NOTES"], on: module)
        #expect(try JSONDecoder().decode([WindowInfo].self, from: Data(notes.output.utf8)).map(\.id) == [20, 21])
        let bad = try await run("windows.list", [], ["space": "elsewhere"], on: module)
        #expect(bad.status == 64)
    }

    @Test func listPrintsATableByDefault() async throws {
        let (module, _) = await module()
        let response = try await run("windows.list", on: module)
        let lines = response.output.split(separator: "\n").map(String.init)
        #expect(lines.first?.hasPrefix("ID") == true)
        #expect(lines.count == 7)
        #expect(lines.contains { $0.contains("GitHub") && $0.hasSuffix("Space 2") })
        #expect(lines.contains { $0.contains("Recipes") && $0.hasSuffix("minimized, hidden") })
    }

    @Test func focusTakesAnIDOrATitle() async throws {
        let (module, source) = await module()
        #expect(try await run("windows.focus", ["11"], on: module).output == "11")
        let byTitle = try await run("windows.focus", [], ["title": "recip"], on: module)
        #expect(byTitle.status == 0 && byTitle.output == "21")
        #expect(await source.focusRequests == [11, 21])
        #expect(try await run("windows.focus", ["999"], on: module).status == 1)
        #expect(try await run("windows.focus", [], ["title": "no such window"], on: module).status == 1)
        #expect(try await run("windows.focus", on: module).status == 64)
        #expect(try await run("windows.focus", ["abc"], on: module).status == 64)
    }

    @Test func closeAndMinimizeGoThroughAccessibility() async throws {
        let (module, source) = await module()
        #expect(try await run("windows.close", ["10"], on: module).status == 0)
        #expect(try await run("windows.minimize", ["20"], on: module).status == 0)
        #expect(await source.performed == ["close 10", "minimize 20"])
        #expect(try await run("windows.close", on: module).status == 64)
        #expect(try await run("windows.minimize", ["999"], on: module).status == 1)
    }

    @Test func thePublicAPIMatchesTheVerbs() async {
        let (module, source) = await module()
        #expect(await module.windows(includeOtherSpaces: true).count == 6)
        let current = await module.windows(includeOtherSpaces: false)
        // Computed outside #expect: the macro cannot expand a bare key-path argument.
        let allCurrent = current.allSatisfy(\.isOnCurrentSpace)
        #expect(allCurrent)
        #expect(await module.focus(windowID: 14))
        #expect(await module.perform(.toggleFullScreen, windowID: 14))
        #expect(await !module.focus(windowID: 12))
        #expect(await source.performed == ["toggleFullScreen 14"])
    }

    @Test func openSwitcherNeedsARunningSwitcherAndAValidShortcut() async throws {
        let (module, _) = await module()
        #expect(try await run("debug.open-switcher", [], ["shortcut": "1"], on: module).status == 1)
        #expect(try await run("debug.open-switcher", [], ["shortcut": "10"], on: module).status == 64)
        #expect(try await run("debug.open-switcher", [], ["shortcut": "x"], on: module).status == 64)
        // Not running: a no-op, never a crash.
        module.show(shortcutIndex: 0)
    }

    @Test func activationWithoutAccessibilityWaitsAndDeactivationRestores() async throws {
        let suite = "oriel.switcher.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        settings[SwitcherSettingKeys.disabledSymbolicHotKeys] = [1, 2]
        let keys = FakeHotKeys()
        keys.setSymbolicHotKey(1, enabled: false)
        keys.setSymbolicHotKey(2, enabled: false)
        let source = await Fixture.source()
        let module = WindowSwitcherModule(
            sourceFactory: { _ in source },
            hotKeys: keys,
            hotKeyGuard: SymbolicHotKeyGuard(installsExitHandlers: false),
            isTrusted: { false }
        )
        await module.activate(context: ModuleContext(
            services: ServiceContainer(keychain: KeychainStore(prefix: suite), permissions: FakePermissions()),
            settings: settings,
            log: Log.logger("tests")
        ))
        // A crashed run's leftovers are repaired first; without Accessibility nothing else starts.
        #expect(keys.isEnabled(1) && keys.isEnabled(2))
        #expect(settings[SwitcherSettingKeys.disabledSymbolicHotKeys].isEmpty)
        #expect(!module.isRunning)
        #expect(await !source.isStarted)
        await module.deactivate()
        #expect(!module.isRunning)
    }

    @Test func theTableAlignsColumnsAndTruncates() {
        let windows = [
            WindowInfo(id: 7, pid: 1, appName: "Safari", bundleID: nil, title: "Short", frame: .zero),
            WindowInfo(
                id: 12345, pid: 2, appName: String(repeating: "A", count: 40), bundleID: nil, title: String(repeating: "t", count: 80),
                frame: .zero, isMinimized: true, isHidden: true
            ),
        ]
        let lines = WindowTable.render(windows).split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("ID     APP"))
        #expect(lines[1].hasPrefix("7      Safari"))
        #expect(lines[2].contains(String(repeating: "A", count: 23) + "…"))
        #expect(lines[2].hasSuffix("minimized, hidden"))
        #expect(WindowTable.render([]) == "No windows.")
    }
}
