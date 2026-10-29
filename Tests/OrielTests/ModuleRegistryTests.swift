import Foundation
@testable import Oriel
import OrielCore
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
