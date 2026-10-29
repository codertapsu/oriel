import AppKit
import NaturalLanguage

/// The system's spelling dictionary, asked which of the words a line-end hyphen split are words
/// (`TextLayout.hyphenatedWords`), so that "search-" and "able" become "searchable" while "well-" and "known" stay
/// "well-known". It checks in the text's language when macOS has a dictionary for it, else in the user's languages.
enum SpellingDictionary {
    static func knownWords(_ words: Set<String>, inTextLike sample: String) -> Set<String> {
        guard !words.isEmpty else { return [] }
        let checker = NSSpellChecker.shared
        let code = NLLanguageRecognizer.dominantLanguage(for: sample)?.rawValue
        let language = code.flatMap { code in checker.availableLanguages.first { $0 == code || $0.hasPrefix("\(code)_") } }
        return words.filter { word in
            let misspelled = checker.checkSpelling(
                of: word,
                startingAt: 0,
                language: language,
                wrap: false,
                inSpellDocumentWithTag: 0,
                wordCount: nil
            )
            return misspelled.location == NSNotFound
        }
    }
}
