import Foundation
import OrielCore

/// App-level settings keys. Each module keeps its own keys.
enum AppSettings {
    static let onboardingCompleted = SettingKey("app.onboardingCompleted", default: false)
    /// Modules the user turned on. The switcher is the only optional one today.
    static let enabledModules = SettingKey("app.enabledModules", default: [ModuleID.windowSwitcher.rawValue])
    static let rosettaWarningShown = SettingKey("app.rosettaWarningShown", default: false)
    static let intelNoticeShown = SettingKey("app.intelNoticeShown", default: false)
    static let lastBootstrapImport = SettingKey<Date?>("app.lastBootstrapImport", default: nil)
}
