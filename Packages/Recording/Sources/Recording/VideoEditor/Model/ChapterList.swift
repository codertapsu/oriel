import Foundation

/// Turns the editor's chapter markers into the chapters of an exported movie (PLAN §17). Pure.
///
/// Exported chapters cover the export from 0:00 to its end without gaps. The chapter that is running where the
/// export starts becomes its first chapter at 0:00; when no marker comes before that point, a chapter named
/// `openingTitle` is added there, as players and YouTube expect the first chapter at 0:00. Markers closer together
/// than `minimumLength` are merged, and so is a marker right at the end.
nonisolated enum ChapterList {
    /// The title of the chapter added at 0:00 when no marker is there.
    static let openingTitle = "Start"
    /// The shortest chapter kept.
    static let minimumLength = 1.0
    /// The longest title kept, in characters.
    static let maximumTitleLength = 200

    /// The chapters of an export of `range` (seconds of the source movie). Empty when no marker falls in or before
    /// the range.
    static func build(_ markers: [ChapterMarker], range: ClosedRange<Double>) -> [ExportedChapter] {
        let length = range.upperBound - range.lowerBound
        guard length > 0, !markers.isEmpty else { return [] }
        let sorted = markers.sorted { $0.time < $1.time }
        let named = sorted.enumerated().map { (time: $0.element.time, title: title($0.element.title, number: $0.offset + 1)) }
        let tolerance = 0.001
        let opening = named.last { $0.time <= range.lowerBound + tolerance }
        var starts: [(start: Double, title: String)] = [(0, opening?.title ?? openingTitle)]
        var usesMarker = opening != nil
        for marker in named where marker.time > range.lowerBound + tolerance && marker.time < range.upperBound {
            let start = marker.time - range.lowerBound
            guard let previous = starts.last else { continue }
            if start - previous.start < minimumLength {
                // A marker just after 0:00 names the opening chapter instead of starting a sliver of one.
                if starts.count == 1, !usesMarker {
                    starts[0].title = marker.title
                    usesMarker = true
                }
                continue
            }
            starts.append((start, marker.title))
            usesMarker = true
        }
        guard usesMarker else { return [] }
        if starts.count > 1, let last = starts.last, length - last.start < minimumLength {
            starts.removeLast()
        }
        return starts.indices.map { index in
            let end = index + 1 < starts.count ? starts[index + 1].start : length
            return ExportedChapter(start: starts[index].start, duration: end - starts[index].start, title: starts[index].title)
        }
    }

    /// A title as a player shows it: on one line, trimmed, at most `maximumTitleLength` characters; "Chapter N"
    /// when nothing is left.
    static func title(_ raw: String, number: Int) -> String {
        let line = raw.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return "Chapter \(number)" }
        return String(line.prefix(maximumTitleLength))
    }
}
