import OrielCore

public extension FeatureGuide {
    /// Disk Space Analyzer's page in the feature tour (PLAN §19).
    nonisolated static let diskAnalyzer = FeatureGuide(
        id: ModuleID.diskAnalyzer.rawValue,
        title: "Disk Space Analyzer",
        symbol: "internaldrive",
        summary: "See where the space on your drives goes, and get it back safely.",
        highlights: [
            Highlight(
                "Scan",
                Sandbox.isActive
                    ? "Scan a drive or a folder you allow; Oriel asks once for each."
                    : "Scan a drive or any folder; a scan of Macintosh HD counts macOS itself."
            ),
            Highlight("See it", "Sunburst, treemap and list views show the biggest consumers as the biggest areas."),
            Highlight("Space Hogs", "Caches, Xcode data, installers, node_modules and the Trash, measured and explained."),
            Highlight("Safe removal", "Move to Trash with Undo. Oriel never touches macOS, your home folder or what apps rely on."),
            Highlight(
                "Clean Up",
                "Oriel checks a folder before anything goes, and recommends the safest way to get its space back.",
                pro: .cleanUp
            ),
            Highlight("Duplicates", "Find copies with the same content.", pro: .duplicates),
            Highlight("Old Files", "Find files you have not opened for a year.", pro: .oldFiles),
            Highlight("What grew", "See how much a folder grew since its last scan, and where.", pro: .scanHistory),
            Highlight("CSV export", "Export a scan to a spreadsheet.", pro: .csvExport),
        ],
        commandID: "openDiskAnalyzer"
    )
}
