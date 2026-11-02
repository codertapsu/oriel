import OrielCore

public extension FeatureGuide {
    /// Clipboard History's page in the feature tour (PLAN §19).
    nonisolated static let clipboardHistory = FeatureGuide(
        id: ModuleID.clipboardHistory.rawValue,
        title: "Clipboard History",
        symbol: "list.clipboard",
        summary: "Everything you copy, kept on this Mac: open it over any app, find an item and use it again.",
        highlights: [
            Highlight(
                "Find and paste",
                Sandbox.isActive
                    ? "Search what you copied, preview it, and copy it back; then press ⌘V."
                    : "Search what you copied, preview it, and paste it into the app you are in."
            ),
            Highlight("Private", "Encrypted on this Mac; what password managers copy is never kept."),
            Highlight("Pins", "Pinned items stay at the top and are never removed. Without Pro, five fit."),
            Highlight(
                "The whole history",
                "Every item kept, and pins without a limit. Without Pro, the last 100 items from the past week show.",
                pro: .clipboardUnlimited
            ),
            Highlight("Text in images", "Search finds the words inside copied images.", pro: .clipboardImageSearch),
            Highlight("Quick paste", "⌘1 to ⌘9 paste the first nine items.", pro: .clipboardQuickPaste),
        ],
        commandID: "showClipboardHistory",
        permissions: [.accessibility, .pasteboard]
    )
}
