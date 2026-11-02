import OrielCore

public extension FeatureGuide {
    /// Translation's page in the feature tour (PLAN §19).
    nonisolated static let translation = FeatureGuide(
        id: ModuleID.translation.rawValue,
        title: "Translation",
        symbol: "character.bubble",
        summary: "Select text anywhere on screen and read its translation drawn over the original, block by block.",
        highlights: [
            Highlight("Translate Area", "Hold ⌥ to peek at the original; click a block to copy its translation."),
            Highlight(
                "On this Mac",
                "Apple Translation works offline once its languages are downloaded; Apple Intelligence runs on this Mac too."
            ),
            Highlight(
                "Translate Under Cursor",
                "Rest the pointer on text anywhere and its translation appears below it.",
                pro: .translateUnderCursor
            ),
            Highlight("Files", "PDFs, Word, web pages, subtitles and images, paragraph by paragraph.", pro: .translateFiles),
            Highlight("Glossaries", "Keep names and terms translated the same way.", pro: .glossaries),
            Highlight("AI Vision", "Send the image itself to a vision model, for stylized or vertical text.", pro: .aiVision),
            Highlight(
                "More providers",
                "DeepL, Google Translate, OpenAI, Anthropic and models on your own computer, such as Ollama.",
                pro: .translationProviders
            ),
        ],
        commandID: "translateArea",
        permissions: [.screenRecording]
    )
}
