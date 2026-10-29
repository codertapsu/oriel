import Foundation

/// The glossary one translation uses (PLAN §17): the active project's terms for the request's language pair. Each
/// provider applies it its own way: DeepL with its glossary API, Google with a Cloud Translation glossary, language
/// models in the prompt (only the terms that occur in the text), and everything else with placeholder tokens.
public struct TranslationGlossary: Sendable, Hashable {
    /// The project the terms come from; nil for terms that belong to none.
    public var projectID: UUID?
    public var projectName: String
    /// The pair the terms were chosen for, as BCP 47 codes. The source is nil when it was not known.
    public var source: String?
    public var target: String?
    public var terms: [GlossaryTerm]
    /// The project's Google Cloud glossary, empty when it names none.
    public var googleGlossary: String

    public init(
        projectID: UUID? = nil,
        projectName: String = "",
        source: String? = nil,
        target: String? = nil,
        terms: [GlossaryTerm] = [],
        googleGlossary: String = ""
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.source = source
        self.target = target
        self.terms = terms
        self.googleGlossary = googleGlossary
    }

    /// No glossary.
    public static let none = TranslationGlossary()

    /// The terms that can be applied: both sides have text.
    var usableTerms: [GlossaryTerm] {
        terms.filter(\.isUsable)
    }

    var isEmpty: Bool {
        usableTerms.isEmpty
    }

    /// The usable terms that occur in any of `texts`, in glossary order.
    func terms(occurringIn texts: [String]) -> [GlossaryTerm] {
        GlossaryMatcher.occurring(usableTerms, in: texts)
    }
}
