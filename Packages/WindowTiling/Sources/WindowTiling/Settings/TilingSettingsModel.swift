import Foundation
import Observation
import OrielCore

/// The live state behind Settings → Window Tiling: whether Accessibility is allowed, read again when the pane appears
/// and whenever Oriel comes to the front (the user coming back from System Settings), never on a timer.
@Observable
final class TilingSettingsModel {
    private(set) var isTrusted = false
    @ObservationIgnored private weak var module: WindowTilingModule?

    init(module: WindowTilingModule) {
        self.module = module
    }

    var settings: SettingsStore? {
        module?.currentSettings
    }

    var isActive: Bool {
        module?.isActive ?? false
    }

    func refresh() {
        let trusted = module?.isAccessibilityTrusted ?? false
        if trusted != isTrusted {
            isTrusted = trusted
        }
    }

    /// The user's shortcut for `action` as text ("⌃⌥←"), or nil when it has none.
    func shortcut(for action: TilingAction) -> String? {
        module?.shortcut(for: action)?.description
    }

    func openAccessibilitySettings() {
        module?.openAccessibilitySettings()
    }
}
