/// One piece of a translated file, in reading order: a paragraph, a heading, a list item, a subtitle cue, a block of
/// text in an image, or something kept as it is (code, a table, front matter).
struct DocumentSegment: Sendable, Hashable, Identifiable {
    let id: Int
    /// What is translated; empty for verbatim segments.
    let text: String
    /// Markdown that goes before the translation in a Markdown export: `## `, `- `, `> `, `1. `.
    var prefix: String = ""
    /// Kept exactly as it is in the file and never translated (code, tables, HTML, front matter).
    var verbatim: String?
    /// The page it is on, from 1, for PDFs.
    var page: Int?
    /// The cue it is, for subtitles.
    var cue: SubtitleCue?
    /// Whether a blank line follows it in Markdown; consecutive list items and table rows have none.
    var endsBlock = true

    var isTranslatable: Bool {
        verbatim == nil && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// What the segment shows as its original: the text, or the verbatim block.
    var original: String {
        verbatim ?? text
    }
}
