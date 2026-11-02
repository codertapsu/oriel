import Foundation
import OrielCore

/// App-level settings keys. Each module keeps its own keys.
enum AppSettings {
    static let onboardingCompleted = SettingKey("app.onboardingCompleted", default: false)
    /// The feature tour opened by itself once, after onboarding (PLAN §19).
    static let featureTourShown = SettingKey("app.featureTourShown", default: false)
    /// Modules the user turned on; every default module is on until turned off.
    static let enabledModules = SettingKey("app.enabledModules", default: defaultModules.map(\.rawValue))
    /// Modules that are on by default, in Settings order.
    static let defaultModules: [ModuleID] = [
        .windowSwitcher, .clipboardHistory, .diskAnalyzer, .activityMonitor, .colorPicker, .screenRuler, .windowTiling,
    ]
    /// Default modules the user has already been given. One that is missing here arrived in an update and is turned on
    /// once, even for a user who had already chosen their tools; the switcher predates the list.
    static let offeredModules = SettingKey("app.offeredModules", default: [ModuleID.windowSwitcher.rawValue])
    static let rosettaWarningShown = SettingKey("app.rosettaWarningShown", default: false)
    static let intelNoticeShown = SettingKey("app.intelNoticeShown", default: false)
    static let lastBootstrapImport = SettingKey<Date?>("app.lastBootstrapImport", default: nil)
    /// Sync settings through iCloud (PLAN §7.16); off until the user turns it on.
    static let syncSettings = SettingKey("app.syncSettings", default: false)
    /// This Mac's random identifier in sync; never synced.
    static let syncDeviceID = SettingKey<String?>("sync.deviceID", default: nil)
    /// When each synced setting last changed on this Mac.
    static let syncModified = SettingKey<[String: Date]>("sync.modified", default: [:])
    /// Whether this Mac has synced once, so it brings its settings only if it was the first.
    static let syncSeeded = SettingKey("sync.seeded", default: false)
}
