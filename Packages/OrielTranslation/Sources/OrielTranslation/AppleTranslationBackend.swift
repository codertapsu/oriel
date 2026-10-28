import Foundation

/// Apple Translation's language-pack state for a pair (`LanguageAvailability.Status`), in Oriel's terms.
enum AppleLanguageStatus: Sendable, Equatable {
    case installed
    /// Supported, but the language pack has to be downloaded first.
    case supported
    case unsupported
}

/// The part of the Translation framework `AppleTranslationProvider` uses. The live implementation is
/// `SystemTranslationBackend`; tests use a fake, so the availability mapping can be checked on any Mac.
protocol AppleTranslationBackend: Sendable {
    func status(from source: Locale.Language, to target: Locale.Language) async -> AppleLanguageStatus

    /// Translates with a headless session; yields segments in the order they finish.
    func translate(
        _ segments: [TranslationSegment],
        from source: Locale.Language,
        to target: Locale.Language
    ) -> AsyncThrowingStream<TranslatedSegment, any Error>
}
