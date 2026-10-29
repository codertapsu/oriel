import AppIntents
import ImageIO

/// Translate Text in an Image (PLAN §7.17): on-device OCR and the default provider, with no window, so it fits
/// automations such as "translate every screenshot in a folder".
struct TranslateImageIntent: AppIntent {
    static let title: LocalizedStringResource = "Translate Text in an Image"
    static let description = IntentDescription(
        "Reads the text in an image on this Mac and returns its translation.",
        categoryName: "Translation"
    )

    @Parameter(title: "Image", supportedContentTypes: [.image])
    var image: IntentFile

    @Parameter(title: "To", description: "A language code such as en, ja or vi; empty uses your default.")
    var target: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Translate the text in \(\.$image)") {
            \.$target
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let translation = try IntentContext.require().hub.translation
        guard let source = CGImageSourceCreateWithData(image.data as CFData, nil),
              let picture = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw OrielIntentError.unreadableImage
        }
        let outcome = try await translation.translateHeadless(image: picture, target: target, providerID: nil)
        return .result(value: outcome.blocks.compactMap(\.translation).joined(separator: "\n\n"))
    }
}
