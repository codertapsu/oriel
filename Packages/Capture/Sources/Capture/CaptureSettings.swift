import Foundation
import OrielCore

/// Capture's settings, all named `capture.*` (Settings → Capture). `SettingsStore.removeAll(withPrefix: "capture.")`
/// resets the pane.
nonisolated enum CaptureSettings {
    static let prefix = "capture."

    static let afterCapture = SettingKey("capture.afterCapture", default: AfterCaptureAction.quickAccess)
    /// Every interactive capture goes to the clipboard as well, whatever the after-capture action, so it is in
    /// Clipboard History even when Quick Access is closed with Esc.
    static let copiesToClipboard = SettingKey("capture.copiesToClipboard", default: true)
    /// A folder path; nil means the Desktop.
    static let saveFolder = SettingKey<String?>("capture.saveFolder", default: nil)
    /// The same folder as a security-scoped bookmark, which the App Store edition's sandbox needs (PLAN §19).
    static let saveFolderBookmark = SettingKey<Data?>("capture.saveFolderBookmark", default: nil)
    static let filenameTemplate = SettingKey("capture.filenameTemplate", default: FilenameTemplate.defaultTemplate)
    static let format = SettingKey("capture.format", default: CaptureImageFormat.png)
    /// HEIC only: capture HDR content and keep it as a gain map (`SCScreenshotConfiguration.dynamicRange`).
    static let keepsHDR = SettingKey("capture.keepsHDR", default: false)
    static let playsSound = SettingKey("capture.playsSound", default: true)
    static let flashes = SettingKey("capture.flashes", default: false)
    static let showsCursor = SettingKey("capture.showsCursor", default: false)
    static let windowShadow = SettingKey("capture.windowShadow", default: true)
    /// The freeze-frame overlay (PLAN §7.2, item 2). Off, the screen stays live while selecting, for video, and the
    /// pick is captured once the overlay has gone.
    static let freezesScreen = SettingKey("capture.freezesScreen", default: true)
    static let showsMagnifier = SettingKey("capture.showsMagnifier", default: true)
    /// Leaves Finder's desktop icons and the desktop widgets out of area, screen and all-displays captures and of the
    /// frozen screen, through the capture filter (`DesktopClutter`); Finder itself is never touched.
    static let hidesDesktopIcons = SettingKey("capture.hidesDesktopIcons", default: false)
    /// Seconds before a Quick Access card goes away by itself; 0 keeps it until closed.
    static let quickAccessSeconds = SettingKey("capture.quickAccessSeconds", default: 10)
    static let quickAccessCorner = SettingKey("capture.quickAccessCorner", default: ScreenCorner.bottomRight)
    /// Capture Text opens the text for editing instead of copying it; ⇧ held while selecting does the other.
    static let textOpensPanel = SettingKey("capture.textOpensPanel", default: false)
    /// Step Capture marks where the user clicked last before each step (its palette's Mark Clicks).
    static let stepsMarkClicks = SettingKey("capture.steps.marksClicks", default: true)
    static let historyEnabled = SettingKey("capture.historyEnabled", default: true)
    /// Days to keep history; 0 keeps everything.
    static let historyRetentionDays = SettingKey("capture.historyRetentionDays", default: 30)
    /// The timer for "Capture with Timer": 3, 5 or 10 seconds.
    static let timerSeconds = SettingKey("capture.timerSeconds", default: 5)
    /// The tallest scrolling capture, in pixels (PLAN §7.3, item 7).
    static let scrollingMaxLength = SettingKey("capture.scrollingMaxLength", default: 30000)
    static let previousArea = SettingKey<StoredRegion?>("capture.previousArea", default: nil)

    static let timerChoices = [3, 5, 10]
    static let retentionChoices = [1, 7, 30, 90, 0]
    static let quickAccessChoices = [0, 5, 10, 20, 30]
}
