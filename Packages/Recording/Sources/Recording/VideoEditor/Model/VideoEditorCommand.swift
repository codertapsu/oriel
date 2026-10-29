/// What a key press, a toolbar item or a button asks a video editor window to do (PLAN §17).
nonisolated enum VideoEditorCommand: Equatable, Sendable {
    /// Space.
    case playPause
    /// J.
    case reverse
    /// K.
    case stop
    /// L.
    case forward
    /// ← and → step by a frame; ⇧← and ⇧→ by a second.
    case stepFrames(Int)
    case stepSeconds(Double)
    /// Home and End.
    case goToStart
    case goToEnd
    /// I and O set the trim; ⌥I and ⌥O clear it.
    case setTrimStart
    case setTrimEnd
    case clearTrimStart
    case clearTrimEnd
    /// M.
    case addChapter
    /// ↑ and ↓.
    case previousChapter
    case nextChapter
    /// Z.
    case addZoom
    case autoZoom
    /// Delete or Forward Delete.
    case delete
    /// Escape.
    case deselect
    case undo
    case redo
    /// ⇧⌘C.
    case copyFrameText
    /// ⌘E.
    case export
    /// ⌘O.
    case open
    /// ⌘W.
    case close
    /// ⌘= and ⌘- zoom the timeline; ⌘0 fits the movie.
    case zoomTimelineIn
    case zoomTimelineOut
    case fitTimeline

    /// Whether the command comes from an arrow key, which a focused list, slider or pop-up button uses itself.
    var usesArrowKeys: Bool {
        switch self {
        case .stepFrames, .stepSeconds, .previousChapter, .nextChapter: true
        default: false
        }
    }
}
