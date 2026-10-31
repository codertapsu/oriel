import Foundation
import NaturalLanguage
import Synchronization

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
        languageCodes(of: [text])[0]
    }

    /// The code of each of `texts`, as `languageCode(of:)` gives it. Reading a line takes the recognizer about 0.4 ms
    /// and making one more, so many texts are read in chunks on every core, each chunk by a recognizer of its own (a
    /// recognizer keeps state and is not safe to share between threads), reset between texts: 500 lines took 0.3 s one
    /// recognizer each, one after the other.
    public static func languageCodes(of texts: [String]) -> [String?] {
        let chunks = max(1, min(ProcessInfo.processInfo.activeProcessorCount, texts.count / minimumChunk))
        guard chunks > 1 else { return codes(of: texts[...]) }
        let size = (texts.count + chunks - 1) / chunks
        let results = Mutex([[String?]](repeating: [], count: chunks))
        DispatchQueue.concurrentPerform(iterations: chunks) { chunk in
            let codes = codes(of: texts[chunk * size ..< min(texts.count, (chunk + 1) * size)])
            results.withLock { $0[chunk] = codes }
        }
        return results.withLock { $0.flatMap(\.self) }
    }

    /// Below this many texts a chunk is not worth a thread.
    private static let minimumChunk = 32

    private static func codes(of texts: ArraySlice<String>) -> [String?] {
        let recognizer = NLLanguageRecognizer()
        return texts.map { text in
            guard text.contains(where: \.isLetter) else { return nil }
            recognizer.reset()
            recognizer.processString(text)
            guard let language = recognizer.dominantLanguage, language != .undetermined else { return nil }
            return language.rawValue
        }
    }
}
