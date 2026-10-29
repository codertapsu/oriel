import CoreGraphics

/// Collects the clicks of one recording while it runs (PLAN §17). Pure, so it is tested without a mouse.
///
/// Each click is kept with the segment file it fell into and its time since that segment opened: the movie's
/// timeline is only known once the segments are joined, so `sidecar(segmentStarts:duration:)` places the clicks on
/// it then. Clicks outside the recorded area, or while paused, are dropped. Recording a click appends one small
/// value; nothing else runs.
nonisolated struct ClickLog: Equatable, Sendable {
    /// A click as it was seen, before the segments were joined.
    struct Entry: Equatable, Sendable {
        /// The index of the segment file the click fell into.
        let segment: Int
        /// Seconds since that segment opened.
        let offset: Double
        let x: Double
        let y: Double
        let button: ClickRecord.Button
    }

    /// The recorded area in Cocoa screen coordinates (y up), as `NSEvent.mouseLocation` reports clicks.
    let area: CGRect
    /// The movie's frame size in pixels.
    let pixelWidth: Int
    let pixelHeight: Int
    private(set) var entries: [Entry] = []

    init(area: CGRect, pixelWidth: Int, pixelHeight: Int) {
        self.area = area.standardized
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    /// Where `location` (Cocoa screen coordinates) falls in `area`, normalized with a top-left origin, or nil when
    /// it is outside.
    static func normalized(_ location: CGPoint, in area: CGRect) -> CGPoint? {
        guard area.width > 0, area.height > 0,
              location.x >= area.minX, location.x <= area.maxX,
              location.y >= area.minY, location.y <= area.maxY
        else {
            return nil
        }
        return CGPoint(x: (location.x - area.minX) / area.width, y: (area.maxY - location.y) / area.height)
    }

    /// Keeps a click at `location` that happened `offset` seconds after segment `segment` opened. Returns whether
    /// it was kept: clicks outside the recorded area, with a negative offset or past the capacity are not.
    @discardableResult
    mutating func record(_ location: CGPoint, button: ClickRecord.Button, segment: Int, offset: Double) -> Bool {
        guard entries.count < ClickSidecar.maximumCount, offset.isFinite, offset >= 0,
              let point = Self.normalized(location, in: area)
        else {
            return false
        }
        entries.append(Entry(segment: segment, offset: offset, x: point.x, y: point.y, button: button))
        return true
    }

    /// Where each joined segment starts in the finished movie, from the segments' durations in recording order. A
    /// segment without a duration (it was dropped as unplayable) has no start, so its clicks are dropped too.
    static func segmentStarts(durations: [(segment: Int, duration: Double?)]) -> [Int: Double] {
        var starts: [Int: Double] = [:]
        var cursor = 0.0
        for (segment, duration) in durations {
            guard let duration, duration.isFinite, duration > 0 else { continue }
            starts[segment] = cursor
            cursor += duration
        }
        return starts
    }

    /// The clicks on the finished movie's timeline, rounded to milliseconds and 1/10,000 of the area.
    func sidecar(segmentStarts: [Int: Double], duration: Double) -> ClickSidecar {
        let clicks = entries.compactMap { entry -> ClickRecord? in
            guard let start = segmentStarts[entry.segment] else { return nil }
            let time = Self.rounded(start + entry.offset, places: 1000)
            guard time <= duration else { return nil }
            return ClickRecord(
                time: time,
                x: Self.rounded(entry.x, places: 10000),
                y: Self.rounded(entry.y, places: 10000),
                button: entry.button
            )
        }
        return ClickSidecar(width: pixelWidth, height: pixelHeight, duration: duration, clicks: clicks)
    }

    private static func rounded(_ value: Double, places: Double) -> Double {
        (value * places).rounded() / places
    }
}
