import Foundation
import NaturalLanguage

/// Guesses the language of recognized text with `NLLanguageRecognizer` (PLAN §4.3, §7.7.2). Apple Translation needs
/// a known source language, and Vision's per-line language reports are not reliable enough for that.
public enum LanguageDetector {
    /// The language most of `texts` is written in, or nil when there is nothing to judge (no letters) or the
    /// recognizer cannot decide.
    public static func dominantLanguage(of texts: [String]) -> Locale.Language? {
        languageCode(of: texts.joined(separator: "\n")).map(Locale.Language.init(identifier:))
    }

    /// The BCP 47 code (`en`, `ja`, `zh-Hans`) of one piece of text, or nil when it has no letters or the
    /// recognizer cannot decide.
    public static func languageCode(of text: String) -> String? {
        guard text.contains(where: \.isLetter) else { return nil }
        // A fresh recognizer per call: NLLanguageRecognizer keeps state and is not safe to share between threads.
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
        return language.rawValue
    }
}
