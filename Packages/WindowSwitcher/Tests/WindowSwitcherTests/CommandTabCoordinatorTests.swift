import Foundation
import OrielCore
import Testing
@testable import WindowSwitcher

/// The takeover keeps settings and the system in step and gives every hot key back (PLAN §7.1.4), against
/// fake hot keys and a private settings suite.
@MainActor
struct CommandTabCoordinatorTests {
    private func makeSettings() throws -> (SettingsStore, UserDefaults, String) {
        let suite = "oriel.switcher.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (SettingsStore(defaults: defaults), defaults, suite)
    }

    private func coordinator(_ settings: SettingsStore, _ keys: FakeHotKeys) -> CommandTabCoordinator {
        CommandTabCoordinator(settings: settings, control: keys, hotKeyGuard: SymbolicHotKeyGuard(installsExitHandlers: false))
    }

    @Test func applyingRecordsBeforeDisablingAndRestoringGivesEverythingBack() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let keys = FakeHotKeys()
        let hotKeyGuard = SymbolicHotKeyGuard(installsExitHandlers: false)
        let coordinator = CommandTabCoordinator(settings: settings, control: keys, hotKeyGuard: hotKeyGuard)

        coordinator.apply(shortcuts: [CommandTabTakeoverTests.commandTab], enabled: true)
        #expect(settings[SwitcherSettingKeys.disabledSymbolicHotKeys] == [1, 2])
        #expect(!keys.isEnabled(1) && !keys.isEnabled(2) && keys.isEnabled(60))
        #expect(hotKeyGuard.disabled == [1, 2])

        // Applying again changes nothing.
        coordinator.apply(shortcuts: [CommandTabTakeoverTests.commandTab], enabled: true)
        #expect(keys.log == ["1 off", "2 off"])

        coordinator.restore()
        #expect(keys.isEnabled(1) && keys.isEnabled(2))
        #expect(settings[SwitcherSettingKeys.disabledSymbolicHotKeys].isEmpty)
        #expect(hotKeyGuard.disabled.isEmpty)
    }

    @Test func changingTheShortcutAwayFromCommandTabGivesItBack() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        let keys = FakeHotKeys()
        let coordinator = coordinator(settings, keys)
        coordinator.apply(shortcuts: [CommandTabTakeoverTests.commandTab], enabled: true)
        coordinator.apply(shortcuts: [.optionTab], enabled: true)
        #expect(keys.isEnabled(1) && keys.isEnabled(2))
        coordinator.apply(shortcuts: [CommandTabTakeoverTests.commandTab], enabled: false)
        #expect(keys.isEnabled(1) && keys.isEnabled(2))
        #expect(coordinator.disabled.isEmpty)
    }

    @Test func leftoversFromACrashAreTurnedBackOnAtActivation() throws {
        let (settings, defaults, suite) = try makeSettings()
        defer { defaults.removePersistentDomain(forName: suite) }
        // A previous run disabled 1 and 2, then was killed with -9.
        let keys = FakeHotKeys()
        keys.setSymbolicHotKey(1, enabled: false)
        keys.setSymbolicHotKey(2, enabled: false)
        settings[SwitcherSettingKeys.disabledSymbolicHotKeys] = [1, 2]

        let coordinator = coordinator(settings, keys)
        coordinator.restoreLeftovers()
        #expect(keys.isEnabled(1) && keys.isEnabled(2))
        #expect(settings[SwitcherSettingKeys.disabledSymbolicHotKeys].isEmpty)
        coordinator.restoreLeftovers()
        #expect(keys.log == ["1 off", "2 off", "1 on", "2 on"])
    }

    @Test func theExitGuardRestoresWhatItTracks() {
        let keys = FakeHotKeys()
        let hotKeyGuard = SymbolicHotKeyGuard(installsExitHandlers: false)
        keys.setSymbolicHotKey(1, enabled: false)
        hotKeyGuard.track([1], control: keys)
        #expect(hotKeyGuard.restore() == [1])
        #expect(keys.isEnabled(1))
        #expect(hotKeyGuard.restore().isEmpty)
    }
}
