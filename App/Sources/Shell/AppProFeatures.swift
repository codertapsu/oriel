import OrielCore

/// What only Oriel Pro unlocks in the app itself (PLAN §19).
extension ProFeature {
    nonisolated static let settingsSync = ProFeature(
        id: "app.sync",
        title: "Settings sync",
        summary: "Keep your shortcuts, tools and preferences the same on every Mac, through iCloud.",
        module: nil
    )
}
