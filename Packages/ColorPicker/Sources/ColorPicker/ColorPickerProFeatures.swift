import OrielCore

/// What only Oriel Pro unlocks in Color Picker (PLAN §19). Picking any color on screen and copying it as HEX, RGB or
/// HSL, with recent colors, stays free.
public extension ProFeature {
    nonisolated static let colorFormats = ProFeature(
        id: "color.formats",
        title: "Every color format",
        summary: "OKLCH, Display P3, HSB, CMYK, RGB % and code for SwiftUI, AppKit and UIKit.",
        module: .colorPicker
    )
    nonisolated static let palettes = ProFeature(
        id: "color.palettes",
        title: "Palettes",
        summary: "Collect colors in palettes and export them as JSON, CSS variables or a color list.",
        module: .colorPicker
    )
    nonisolated static let contrastChecker = ProFeature(
        id: "color.contrast",
        title: "Contrast checker",
        summary: "Check text and background colors against WCAG 2.2 AA and AAA.",
        module: .colorPicker
    )

    /// Color Picker's Pro features, in the order Settings → Oriel Pro lists them.
    nonisolated static let colorPickerFeatures: [ProFeature] = [.colorFormats, .palettes, .contrastChecker]
}
