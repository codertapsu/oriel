/// One click during a recording, as Auto Zoom needs it: when it happened on the movie's timeline, where it was in
/// the recorded area, and which button it was (PLAN §17).
///
/// Positions are normalized to the recorded area with a top-left origin, the movie's own orientation, so they do
/// not depend on the display's scale or on the size the movie is later exported at.
nonisolated struct ClickRecord: Codable, Equatable, Sendable {
    /// The mouse button that went down.
    enum Button: String, Codable, Sendable {
        case left
        case right
        case other
    }

    /// Seconds from the start of the movie.
    var time: Double
    /// 0 at the recorded area's left edge, 1 at its right edge.
    var x: Double
    /// 0 at the recorded area's top edge, 1 at its bottom edge.
    var y: Double
    var button: Button

    init(time: Double, x: Double, y: Double, button: Button = .left) {
        self.time = time
        self.x = x
        self.y = y
        self.button = button
    }

    /// Whether the record can be used: a finite, non-negative time and a position inside the recorded area.
    var isValid: Bool {
        time.isFinite && time >= 0 && x.isFinite && y.isFinite && (0 ... 1).contains(x) && (0 ... 1).contains(y)
    }
}
