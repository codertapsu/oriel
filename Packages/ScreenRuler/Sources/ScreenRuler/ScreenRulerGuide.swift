import OrielCore

public extension FeatureGuide {
    /// The Screen Ruler's page in the feature tour (PLAN §19).
    nonisolated static let screenRuler = FeatureGuide(
        id: ModuleID.screenRuler.rawValue,
        title: "Screen Ruler",
        symbol: "ruler",
        summary: "Measure anything on screen, in points or pixels.",
        highlights: [
            Highlight("Dimensions", "Lines run from the pointer to the nearest edges; drag a box to fit it to a button."),
            Highlight("Measure Area", "Drag a rectangle to read its size and position; its edges snap to what is on screen."),
            Highlight("Guides", "Lay guide lines and read the distances between them.", pro: .rulerGuides),
            Highlight("Kept measurements", "Click to keep a box on screen while you measure the next.", pro: .keptMeasurements),
            Highlight("Tolerance and color", "Tune how edges are found, and the ruler's color.", pro: .rulerStyle),
        ],
        commandID: "openScreenRuler",
        permissions: [.screenRecording]
    )
}
