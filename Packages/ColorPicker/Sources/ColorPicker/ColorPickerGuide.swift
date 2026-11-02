import OrielCore

public extension FeatureGuide {
    /// The Color Picker's page in the feature tour (PLAN §19).
    nonisolated static let colorPicker = FeatureGuide(
        id: ModuleID.colorPicker.rawValue,
        title: "Color Picker",
        symbol: "eyedropper",
        summary: "Pick any pixel on screen and copy its color in the format you need.",
        highlights: [
            Highlight("Pick anywhere", "The loupe picks any pixel, and the color is copied at once."),
            Highlight("Everyday formats", "HEX, RGB and HSL, with or without alpha."),
            Highlight(
                "Every format",
                "HSB, OKLCH, Display P3, CMYK, and SwiftUI, NSColor and UIColor code.",
                pro: .colorFormats
            ),
            Highlight("Palettes", "Collect colors and export them as JSON, CSS variables or a color list.", pro: .palettes),
            Highlight("Contrast", "WCAG 2.2 and APCA contrast for a text and a background color.", pro: .contrastChecker),
        ],
        commandID: "pickColor"
    )
}
