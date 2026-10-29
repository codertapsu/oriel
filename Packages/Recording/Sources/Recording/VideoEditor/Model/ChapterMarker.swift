import Foundation

/// A chapter marker the user put on the timeline (PLAN §17): a chapter starts at `time`.
nonisolated struct ChapterMarker: Equatable, Identifiable, Sendable {
    let id: UUID
    /// Seconds from the start of the movie.
    var time: Double
    /// As typed; `ChapterList` names an empty one "Chapter N".
    var title: String

    init(id: UUID = UUID(), time: Double, title: String) {
        self.id = id
        self.time = time
        self.title = title
    }
}
