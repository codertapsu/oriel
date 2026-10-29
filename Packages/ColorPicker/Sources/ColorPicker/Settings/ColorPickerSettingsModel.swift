import Foundation
import Observation
import OrielCore

/// What Settings → Color Picker shows that is not a setting: whether the tool is on, its shortcut, and how many recent
/// colors there are to clear.
@Observable
final class ColorPickerSettingsModel {
    private(set) var recentCount = 0
    private(set) var paletteCount = 0
    @ObservationIgnored private weak var module: ColorPickerModule?

    init(module: ColorPickerModule) {
        self.module = module
    }

    var settings: SettingsStore? {
        module?.currentSettings
    }

    var isActive: Bool {
        module?.isActive ?? false
    }

    var shortcut: String? {
        module?.pickShortcutDescription
    }

    /// The color the format examples are written for: the current one, or an orange (#FF8800).
    var exampleColor: ColorValue {
        module?.model?.current ?? ColorValue(red: 1, green: 136.0 / 255, blue: 0)
    }

    func refresh() {
        let library = module?.model?.library
        let recent = library?.history.count ?? 0
        let palettes = library?.palettes.count ?? 0
        if recent != recentCount {
            recentCount = recent
        }
        if palettes != paletteCount {
            paletteCount = palettes
        }
    }

    func clearRecent() {
        module?.model?.change { $0.clearHistory() }
    }
}
