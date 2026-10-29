import Foundation

/// The markup inside subtitle cues: WebVTT and SRT tags (`<i>`, `<b>`, `<c.yellow>`, `<v Alice>`, `<00:01.500>`),
/// SRT's `{\an8}` positions, ruby text and HTML entities. Translation gets plain text; the voice or position at the
/// start of a cue is put back in front of the translation, and inline styling is dropped.
enum SubtitleMarkup {
    static func plainText(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: "<rt>[^<]*</rt>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\{\\[^}]*\}"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>\n]*>", with: "", options: .regularExpression)
        text = HTMLEntities.decode(text)
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    /// `<v Alice>` (or `<v.loud Alice>`) or `{\an8}` at the very start, else "".
    static func leadingTag(of raw: String) -> String {
        let trimmed = raw.drop { $0 == " " }
        if trimmed.hasPrefix("<v"), let end = trimmed.firstIndex(of: ">") {
            let tag = trimmed[...end]
            if tag.count > 2, tag.dropFirst(2).first.map({ $0 == " " || $0 == "." }) == true {
                return String(tag)
            }
        }
        if trimmed.hasPrefix(#"{\an"#), let end = trimmed.firstIndex(of: "}") {
            return String(trimmed[...end])
        }
        return ""
    }

    /// Text for a WebVTT cue: `&`, `<` and `>` escaped, as the format requires.
    static func escapedForVTT(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
