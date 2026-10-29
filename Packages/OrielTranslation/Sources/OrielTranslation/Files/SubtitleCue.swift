/// One subtitle cue (PLAN §17): its timing, which translation never changes, and its text.
struct SubtitleCue: Sendable, Hashable {
    /// The identifier line WebVTT cues may have. SRT numbers are not kept: the writer numbers cues again.
    var identifier: String?
    /// Milliseconds from the start of the video.
    var start: Int
    var end: Int
    /// WebVTT cue settings after the timing (`align:start position:10%`), written back to WebVTT.
    var settings: String
    /// The text as the file has it, markup included.
    var rawText: String

    /// A leading WebVTT voice (`<v Alice>`) or SRT position (`{\an8}`), put back in front of the translation.
    var leadingTag: String {
        SubtitleMarkup.leadingTag(of: rawText)
    }

    /// What is translated: the text without markup or entities, one line per line of the cue.
    var plainText: String {
        SubtitleMarkup.plainText(rawText)
    }
}
