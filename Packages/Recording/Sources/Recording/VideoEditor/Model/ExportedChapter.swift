/// One chapter of an exported movie: a stretch of its timeline with a title. Chapters cover the timeline from 0 to
/// the end without gaps, which is what a QuickTime chapter track needs.
nonisolated struct ExportedChapter: Equatable, Sendable {
    /// Seconds from the start of the exported movie.
    var start: Double
    var duration: Double
    var title: String

    var end: Double {
        start + duration
    }
}
