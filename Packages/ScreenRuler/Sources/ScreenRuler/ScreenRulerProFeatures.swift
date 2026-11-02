import OrielCore

/// What only Oriel Pro unlocks in Screen Ruler (PLAN §19). Dimensions, Measure Area, fitting a box to what is under it,
/// and copying any measurement stay free.
public extension ProFeature {
    nonisolated static let rulerGuides = ProFeature(
        id: "ruler.guides",
        title: "Guides",
        summary: "Lay guide lines across the screen and read the distances between them.",
        module: .screenRuler
    )
    nonisolated static let keptMeasurements = ProFeature(
        id: "ruler.kept",
        title: "Kept measurements",
        summary: "Click to keep a measurement on the screen while you look at the next.",
        module: .screenRuler
    )
    nonisolated static let rulerStyle = ProFeature(
        id: "ruler.style",
        title: "Ruler color and edge tolerance",
        summary: "Choose the ruler's color and how strong an edge has to be to count.",
        module: .screenRuler
    )

    /// Screen Ruler's Pro features, in the order Settings → Oriel Pro lists them.
    nonisolated static let screenRulerFeatures: [ProFeature] = [.rulerGuides, .keptMeasurements, .rulerStyle]
}
