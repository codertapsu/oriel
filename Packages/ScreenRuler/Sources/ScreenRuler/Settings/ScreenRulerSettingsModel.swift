import Foundation
import Observation
import OrielCore

/// What Settings → Screen Ruler shows besides the settings: whether the tool is on, its shortcut, and whether
/// Dimensions can read the screen.
@Observable
final class ScreenRulerSettingsModel {
    private(set) var screenRecording = PermissionStatus.notDetermined
    @ObservationIgnored private weak var module: ScreenRulerModule?

    init(module: ScreenRulerModule) {
        self.module = module
    }

    var settings: SettingsStore? {
        module?.currentSettings
    }

    var isActive: Bool {
        module?.isActive ?? false
    }

    var shortcut: String? {
        module?.shortcutDescription
    }

    var canAskForScreenRecording: Bool {
        module?.permissions != nil
    }

    /// Reads the permission again; only through its public check, which never asks.
    func refresh() {
        let status = module?.permissions?.status(of: .screenRecording) ?? .notDetermined
        if status != screenRecording {
            screenRecording = status
        }
    }

    func openScreenRecordingSettings() {
        module?.permissions?.openSystemSettings(for: .screenRecording)
    }
}
