import OrielCore

/// What only Oriel Pro unlocks in Clipboard History (PLAN §19). Without it the panel shows the last 100 items from the
/// past seven days, keeps up to five pinned, and searches their text; everything copied is still kept to the limits in
/// Settings, so Pro shows it all at once.
public extension ProFeature {
    nonisolated static let clipboardUnlimited = ProFeature(
        id: "clipboard.unlimited",
        title: "Your whole clipboard history",
        summary: "See everything you copied, up to your own limits, and pin as many items as you like.",
        module: .clipboardHistory
    )
    nonisolated static let clipboardImageSearch = ProFeature(
        id: "clipboard.imageSearch",
        title: "Search inside images",
        summary: "Find a copied screenshot or image by the text in it.",
        module: .clipboardHistory
    )
    nonisolated static let clipboardQuickPaste = ProFeature(
        id: "clipboard.quickPaste",
        title: "⌘1–⌘9",
        summary: "Paste one of the first nine items with a keystroke.",
        module: .clipboardHistory
    )

    /// Clipboard History's Pro features, in the order Settings → Oriel Pro lists them.
    nonisolated static let clipboardFeatures: [ProFeature] = [.clipboardUnlimited, .clipboardImageSearch, .clipboardQuickPaste]
}
