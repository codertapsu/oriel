import OrielCore

/// What only Oriel Pro unlocks in Disk Space Analyzer (PLAN §19). Scanning, the sunburst, the treemap, the list,
/// Biggest Files, File Types, Space Hogs and moving things to the Trash stay free.
public extension ProFeature {
    nonisolated static let cleanUp = ProFeature(
        id: "disk.cleanUp",
        title: "Clean Up",
        summary: "Have Oriel check a folder and recommend the safest way to get its space back.",
        module: .diskAnalyzer
    )
    nonisolated static let duplicates = ProFeature(
        id: "disk.duplicates",
        title: "Duplicates",
        summary: "Find copies of the same file and keep the newest or oldest.",
        module: .diskAnalyzer
    )
    nonisolated static let oldFiles = ProFeature(
        id: "disk.oldFiles",
        title: "Old Files",
        summary: "List the files you have not opened for a year, or another span.",
        module: .diskAnalyzer
    )
    nonisolated static let scanHistory = ProFeature(
        id: "disk.history",
        title: "What grew",
        summary: "See how much a folder grew since its last scan, and which folders it was.",
        module: .diskAnalyzer
    )
    nonisolated static let csvExport = ProFeature(
        id: "disk.csv",
        title: "Export as CSV",
        summary: "Export a scan as a spreadsheet.",
        module: .diskAnalyzer
    )

    /// Disk Space Analyzer's Pro features, in the order Settings → Oriel Pro lists them.
    nonisolated static let diskAnalyzerFeatures: [ProFeature] = [.cleanUp, .duplicates, .oldFiles, .scanHistory, .csvExport]
}
