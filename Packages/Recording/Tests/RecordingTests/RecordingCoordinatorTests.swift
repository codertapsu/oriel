import Foundation
import OrielCore
import Permissions
@testable import Recording
import Testing

/// Only what can run without recording, prompting or showing a window: `start` is never called here.
@MainActor
struct RecordingCoordinatorTests {
    @Test func isIdleUntilStartedAndIgnoresPauseAndStop() async throws {
        let suite = "oriel-recording-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = RecordingCoordinator(settings: SettingsStore(defaults: defaults), permissions: PermissionCenter())
        var changes: [RecordingState] = []
        coordinator.onStateChange = { changes.append($0) }

        #expect(coordinator.state == .idle)
        #expect(!coordinator.isActive)
        await coordinator.togglePause()
        await coordinator.stop()

        #expect(coordinator.state == .idle)
        #expect(changes.isEmpty)
    }

    @Test func offersASettingsPane() throws {
        let suite = "oriel-recording-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = RecordingCoordinator(settings: SettingsStore(defaults: defaults), permissions: PermissionCenter())
        _ = coordinator.settingsPane
    }

    @Test func offersOpenVideoInTheLibrary() throws {
        let suite = "oriel-recording-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let coordinator = RecordingCoordinator(settings: SettingsStore(defaults: defaults), permissions: PermissionCenter())

        let command = try #require(coordinator.commands.first { $0.id == "openVideoEditor" })
        #expect(command.title == "Open Video…")
        #expect(command.group == .library)
        #expect(command.defaultShortcut == nil)
        #expect(command.route == "video/open")
        #expect(command.showsInMenu)
    }

    @Test func remembersClicksUnlessTurnedOff() throws {
        let suite = "oriel-recording-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        #expect(RecordingOptions(settings: settings).remembersClicks)
        #expect(RecordingOptions(settings: settings).cameraBackground == .unchanged)
        settings[RecordingSettingKeys.remembersClicks] = false
        #expect(!RecordingOptions(settings: settings).remembersClicks)
    }

    @Test func targetsCompareByValue() {
        let region = CGRect(x: 10, y: 20, width: 300, height: 200)
        #expect(RecordingTarget.region(region, displayID: 1) == .region(region, displayID: 1))
        #expect(RecordingTarget.region(region, displayID: 1) != .region(region, displayID: 2))
        #expect(RecordingTarget.display(1) != .window(1))
    }

    @Test func presetsDescribeThemselves() {
        for preset in RecordingPreset.allCases {
            #expect(preset.displayName.contains("\(preset.frameRate) fps"))
            #expect(preset.displayName.contains(preset.codec.displayName))
        }
    }
}
