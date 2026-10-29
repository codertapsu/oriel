import AppIntents

/// Translate Area (PLAN §7.17): the user selects text on the screen and gets its translation as text.
struct TranslateAreaIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate Area"
    static let description = IntentDescription(
        "Translates the text in an area you select on the screen and returns the translation.",
        categoryName: "Translation"
    )

    @Parameter(title: "To", description: "A language code such as en, ja or vi; empty uses your default.")
    var target: String?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let hub = try IntentContext.require().hub
        guard let region = await hub.capture.selectRegion(prompt: "Select the text to translate") else {
            throw OrielIntentError.cancelled
        }
        let shot = try await hub.capture.captureRect(region.rect)
        let outcome = try await hub.translation.translateHeadless(image: shot.image, target: target, providerID: nil)
        return .result(value: outcome.blocks.compactMap(\.translation).joined(separator: "\n\n"))
    }
}
