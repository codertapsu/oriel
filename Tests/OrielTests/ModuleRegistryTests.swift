import AppKit
import Foundation
@testable import Oriel
import OrielCore
import SwiftUI
import Testing

/// A tool that arrives in an update is turned on once, also for a user who had already chosen their tools, and stays
/// off once they turn it off (PLAN §6.3).
@MainActor
struct ModuleRegistryTests {
    private func registry() throws -> (ModuleRegistry, SettingsStore, String) {
        let suiteName = "com.codertapsu.oriel.tests.modules.\(UUID().uuidString)"
        let settings = try SettingsStore(defaults: #require(UserDefaults(suiteName: suiteName)))
        let services = ServiceContainer(keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests"), permissions: FakePermissions())
        return (ModuleRegistry(settings: settings, services: services, modules: []), settings, suiteName)
    }

    @Test func aFreshInstallHasEveryDefaultToolOn() throws {
        let (registry, settings, suite) = try registry()
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        registry.enableNewDefaultModules()
        #expect(registry.isEnabled(.windowSwitcher))
        #expect(registry.isEnabled(.clipboardHistory))
        #expect(!settings.hasValue(AppSettings.enabledModules))
    }

    @Test func anUpdateTurnsTheNewToolOnOnceAndKeepsTheUsersChoices() throws {
        let (registry, settings, suite) = try registry()
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        // A build from before Clipboard History: the user turned the switcher off.
        settings[AppSettings.enabledModules] = []
        registry.enableNewDefaultModules()
        #expect(!registry.isEnabled(.windowSwitcher))
        #expect(registry.isEnabled(.clipboardHistory))
        // Turned off later, it stays off.
        settings[AppSettings.enabledModules] = []
        registry.enableNewDefaultModules()
        #expect(!registry.isEnabled(.clipboardHistory))
    }
}

/// A tool's commands are registered while it is on and listed in the menu while it runs; a change of the tools that
/// did not go through `setEnabled`, as from settings sync, starts and stops them (PLAN §6.3, §6.5).
@MainActor
struct ModuleRegistryCommandTests {
    @Test func commandsFollowTheToolsThatAreOnAndTheMenuTheToolsThatRun() async throws {
        let suiteName = "com.codertapsu.oriel.tests.commands.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let settings = try SettingsStore(defaults: #require(UserDefaults(suiteName: suiteName)))
        let services = ServiceContainer(keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests"), permissions: FakePermissions())
        let tool = FakeTool()
        let registry = ModuleRegistry(settings: settings, services: services, modules: [tool])

        settings[AppSettings.enabledModules] = []
        #expect(registry.commands.isEmpty)
        settings[AppSettings.enabledModules] = [FakeTool.id.rawValue]
        #expect(registry.commands.map(\.id) == ["fakeOpen"])
        #expect(registry.enabledModulesWithCommands.count == 1)
        #expect(registry.menuCommands.isEmpty, "the tool is not running yet")

        await registry.applyEnabledModules()
        #expect(tool.isActive)
        #expect(registry.menuCommands.map(\.id) == ["fakeOpen"])

        settings[AppSettings.enabledModules] = []
        await registry.applyEnabledModules()
        #expect(!tool.isActive)
        #expect(registry.commands.isEmpty && registry.menuCommands.isEmpty)
    }
}

/// A tool with one command.
@MainActor
private final class FakeTool: UtilityModule {
    static let id: ModuleID = "fake-tool"
    let displayName = "Fake Tool"
    private(set) var isActive = false

    var requiredPermissions: Set<PermissionKind> {
        []
    }

    var menuItems: [NSMenuItem] {
        []
    }

    var settingsPane: AnyView? {
        nil
    }

    var ipcCommands: [IPCCommandHandler] {
        []
    }

    var commands: [ToolCommand] {
        [ToolCommand(id: "fakeOpen", title: "Fake Tool", symbol: "hammer", group: .tools) {}]
    }

    func activate(context _: ModuleContext) async {
        isActive = true
    }

    func deactivate() async {
        isActive = false
    }
}

/// Permissions that are never granted and never prompt.
@MainActor
private final class FakePermissions: PermissionChecking {
    func status(of _: PermissionKind) -> PermissionStatus {
        .notDetermined
    }

    func request(_: PermissionKind) async -> PermissionStatus {
        .notDetermined
    }

    func openSystemSettings(for _: PermissionKind) {}
}
