import Foundation
import OrielCore

/// App-level settings keys. Each module keeps its own keys.
enum AppSettings {
    static let onboardingCompleted = SettingKey("app.onboardingCompleted", default: false)
    /// Modules the user turned on; both are on until turned off.
    static let enabledModules = SettingKey("app.enabledModules", default: defaultModules.map(\.rawValue))
    /// Modules that are on by default, in Settings order.
    static let defaultModules: [ModuleID] = [.windowSwitcher, .clipboardHistory]
    /// Default modules the user has already been given. One that is missing here arrived in an update and is turned on
    /// once, even for a user who had already chosen their tools; the switcher predates the list.
    static let offeredModules = SettingKey("app.offeredModules", default: [ModuleID.windowSwitcher.rawValue])
    static let rosettaWarningShown = SettingKey("app.rosettaWarningShown", default: false)
    static let intelNoticeShown = SettingKey("app.intelNoticeShown", default: false)
    static let lastBootstrapImport = SettingKey<Date?>("app.lastBootstrapImport", default: nil)
}
