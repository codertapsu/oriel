import OrielCore

/// What only Oriel Pro unlocks in translation (PLAN §19). Translate Area with Apple Translation, offline, and with
/// Apple Intelligence on this Mac stays free.
public extension ProFeature {
    nonisolated static let translateUnderCursor = ProFeature(
        id: "translation.underCursor",
        title: "Translate Under Cursor",
        summary: "Rest the pointer on text anywhere to see its translation below it.",
        module: .translation
    )
    nonisolated static let translateFiles = ProFeature(
        id: "translation.files",
        title: "Translate files",
        summary: "Translate images, PDFs, Word and text documents, web pages and subtitles, and export the result.",
        module: .translation
    )
    nonisolated static let glossaries = ProFeature(
        id: "translation.glossaries",
        title: "Glossaries",
        summary: "Keep names and terms translated the same way, with DeepL's and Google's own glossaries.",
        module: .translation
    )
    nonisolated static let aiVision = ProFeature(
        id: "translation.aiVision",
        title: "AI Vision",
        summary: "Send the image itself to a vision model, for stylized or vertical text.",
        module: .translation
    )
    nonisolated static let translationProviders = ProFeature(
        id: "translation.providers",
        title: "Cloud and local models",
        summary: "Translate with OpenAI, Anthropic, Google, DeepL or a model running on your own server.",
        module: .translation
    )

    /// Translation's Pro features, in the order Settings → Oriel Pro lists them.
    nonisolated static let translationFeatures: [ProFeature] = [
        .translateUnderCursor, .translateFiles, .glossaries, .aiVision, .translationProviders,
    ]
}
