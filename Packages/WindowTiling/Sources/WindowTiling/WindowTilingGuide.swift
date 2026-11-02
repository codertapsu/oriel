import OrielCore

public extension FeatureGuide {
    /// Window Tiling's page in the feature tour (PLAN §19).
    nonisolated static let windowTiling = FeatureGuide(
        id: ModuleID.windowTiling.rawValue,
        title: "Window Tiling",
        symbol: "rectangle.split.2x1",
        summary: "Arrange the window you are working in from the keyboard: ⌃⌥ with an arrow tiles it to that half.",
        highlights: [
            Highlight("Halves, quarters and thirds", "Press a half again and the window cycles through two thirds and one third."),
            Highlight("Other displays", "Move a window to the next display; it keeps its layout."),
            Highlight("Restore", "Put the window back where it was before you arranged it."),
        ],
        permissions: [.accessibility]
    )
}
