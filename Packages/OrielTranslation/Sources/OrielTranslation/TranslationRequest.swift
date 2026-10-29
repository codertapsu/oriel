import CoreGraphics
import Foundation

/// What to translate (PLAN §7.7.1).
public struct TranslationRequest: Sendable {
    public var segments: [TranslationSegment]
    /// Nil means "detect it" (providers without `.autoDetect` detect it with NaturalLanguage first).
    public var source: Locale.Language?
    public var target: Locale.Language
    /// The capture, sent only to `.imageInput` providers in AI Vision mode.
    public var image: CGImage?
    /// Fixed translations for terms, from the active glossary project (`TranslationGlossary`).
    public var glossary: TranslationGlossary

    public init(
        segments: [TranslationSegment],
        source: Locale.Language? = nil,
        target: Locale.Language,
        image: CGImage? = nil,
        glossary: TranslationGlossary = .none
    ) {
        self.segments = segments
        self.source = source
        self.target = target
        self.image = image
        self.glossary = glossary
    }

    /// Characters sent for translation, for usage counters.
    var characterCount: Int {
        segments.reduce(0) { $0 + $1.text.count }
    }
}
