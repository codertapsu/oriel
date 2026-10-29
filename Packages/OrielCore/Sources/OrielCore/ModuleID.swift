/// Identifies a utility module (one tool of the app) in the registry, in settings and in logs.
public struct ModuleID: RawRepresentable, Hashable, Codable, Sendable, ExpressibleByStringLiteral, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }

    public var description: String {
        rawValue
    }

    public static let windowSwitcher: ModuleID = "window-switcher"
    public static let capture: ModuleID = "capture"
    public static let recording: ModuleID = "recording"
    public static let translation: ModuleID = "translation"
    public static let editor: ModuleID = "editor"
    public static let clipboardHistory: ModuleID = "clipboard-history"
    public static let diskAnalyzer: ModuleID = "disk-analyzer"
    public static let activityMonitor: ModuleID = "activity-monitor"
    public static let colorPicker: ModuleID = "color-picker"
    public static let screenRuler: ModuleID = "screen-ruler"
    public static let windowTiling: ModuleID = "window-tiling"
}
