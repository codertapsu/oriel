import Observation
import OrielCore

/// The state and the action of Settings → Activity Monitor.
@Observable
final class ActivitySettingsModel {
    private(set) var isActive = false
    private(set) var isWindowOpen = false
    @ObservationIgnored private weak var module: ActivityMonitorModule?

    init(module: ActivityMonitorModule) {
        self.module = module
    }

    var settings: SettingsStore? {
        module?.currentSettings
    }

    func refresh() {
        let active = module?.isActive ?? false
        if active != isActive {
            isActive = active
        }
        let open = module?.isWindowOpen ?? false
        if open != isWindowOpen {
            isWindowOpen = open
        }
    }

    func openWindow() {
        module?.openWindow()
    }
}
