import CoreGraphics
import OrielCore

/// The settings a new editor window starts from, read once when it opens.
nonisolated struct EditorDefaults: Equatable, Sendable {
    var color: RGBAColor = .red
    var strokeWidth: CGFloat = ToolStyle.defaultWidth
    var exportFormat: EditorExportFormat = .png
    var backgroundPreset: BackgroundPreset = .none

    init() {}

    init(color: RGBAColor, strokeWidth: CGFloat, exportFormat: EditorExportFormat, backgroundPreset: BackgroundPreset) {
        self.color = color
        self.strokeWidth = ToolStyle.clampedWidth(strokeWidth)
        self.exportFormat = exportFormat
        self.backgroundPreset = backgroundPreset
    }

    @MainActor
    init(settings: SettingsStore) {
        self.init(
            color: settings[EditorSettings.defaultColor],
            strokeWidth: CGFloat(settings[EditorSettings.strokeWidth]),
            exportFormat: settings[EditorSettings.exportFormat],
            backgroundPreset: settings[EditorSettings.backgroundPreset]
        )
    }
}
