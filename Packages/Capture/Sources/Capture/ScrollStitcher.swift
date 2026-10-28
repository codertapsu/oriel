import CoreGraphics

/// Stitches the frames of a scrolling capture into one tall (or, transposed, wide) image (PLAN §7.3, items 5–10).
///
/// Each new frame is matched against the previous one: rows that stayed put at the top and bottom are a sticky header
/// and footer, left out of the matching and drawn once; the rightmost `maskWidth` columns are ignored (overlay
/// scrollbars); the offset maximizes the correlation of the row signatures within ±25 % of the expected scroll, then
/// the overlap is checked pixel by pixel. A frame equal to the previous one means the end; a frame that cannot be
/// lined up is rejected, so the caller can fail fast and suggest manual mode. Pure and synchronous: tests feed it
/// synthetic frames, and the session runs it off the main thread.
nonisolated struct ScrollStitcher: Sendable {
    struct Configuration: Sendable, Equatable {
        /// The longest result, in pixels along the scroll direction (PLAN §7.3, item 7).
        var maxLength = 30000
        /// Rightmost columns ignored when matching, where overlay scrollbars appear.
        var maskWidth = 16
        /// The lowest normalized cross-correlation accepted.
        var minimumScore = 0.95
        /// The highest mean grey difference of the matched overlap accepted.
        var maximumDifference = 8.0
        /// How far the offset may be from the expected one: ±25 % keeps repeated rows from matching one row off.
        var searchTolerance = 0.25
        /// Mean grey difference under which two frames are the same, i.e. nothing scrolled.
        var sameTolerance = 0.5
        /// Mean grey difference under which a row counts as unchanged, for sticky bands.
        var stickyTolerance = 1.0
        /// Rows the frames have to share.
        var minimumOverlap = 16
        /// Signature bins per row.
        var bins = 32
    }

    enum Step: Sendable, Equatable {
        /// The frame was lined up `offset` rows below the previous one and its new rows were added.
        case appended(offset: Int)
        /// The frame is the same as the previous one: the content did not move, so it has ended.
        case endReached
        /// The result is `maxLength` long; later frames are ignored.
        case limitReached
        /// The frame could not be lined up with enough confidence.
        case lowConfidence
    }

    let direction: ScrollDirection
    let configuration: Configuration
    /// Frames accepted, the first included.
    private(set) var frameCount = 1
    private(set) var isComplete = false
    private let first: PixelFrame
    private var last: PixelFrame
    private var lastGray: GrayFrame
    private var lastSignatures: RowSignatures
    private var canvas: StitchCanvas?
    /// Rows the content has scrolled since the first frame.
    private var scrolled = 0
    private var footer = 0
    private var isFinished = false

    init(first frame: PixelFrame, direction: ScrollDirection = .vertical, configuration: Configuration = Configuration()) {
        let oriented = direction == .horizontal ? frame.transposed() : frame
        self.direction = direction
        self.configuration = configuration
        first = oriented
        last = oriented
        lastGray = GrayFrame(oriented, maskWidth: configuration.maskWidth)
        lastSignatures = RowSignatures(lastGray, bins: configuration.bins)
    }

    /// The result's length so far, in pixels along the scroll direction.
    var length: Int {
        guard let canvas else { return first.height }
        return canvas.height + footer
    }

    /// Matches `frame` against the previous one and adds its new rows. `expectedOffset` is the scroll that was asked
    /// for, in pixels (auto mode); nil searches every offset and rejects ambiguous matches (manual mode).
    mutating func add(_ frame: PixelFrame, expectedOffset: Int?) -> Step {
        guard !isComplete, !isFinished else { return .limitReached }
        let oriented = direction == .horizontal ? frame.transposed() : frame
        guard oriented.width == last.width, oriented.height == last.height else { return .lowConfidence }
        let gray = GrayFrame(oriented, maskWidth: configuration.maskWidth)
        if gray.matches(lastGray, tolerance: configuration.sameTolerance) {
            return .endReached
        }
        let bands = lastGray.stickyBands(comparedWith: gray, tolerance: configuration.stickyTolerance)
        let signatures = RowSignatures(gray, bins: configuration.bins)
        guard let offset = matchOffset(gray: gray, signatures: signatures, bands: bands, expected: expectedOffset) else {
            return .lowConfidence
        }
        let step = compose(oriented, offset: offset, footer: bands.footer)
        last = oriented
        lastGray = gray
        lastSignatures = signatures
        frameCount += 1
        return step
    }

    /// The stitched frames plus the footer of the last one, in the capture's orientation. Call once, at the end.
    mutating func finish() -> PixelFrame {
        guard canvas != nil else { return oriented(first) }
        if !isFinished {
            isFinished = true
            let start = max(last.height - footer, (canvas?.height ?? 0) - scrolled)
            canvas?.append(rows: start ..< last.height, of: last)
        }
        return oriented(canvas?.makeFrame() ?? first)
    }

    private func matchOffset(gray: GrayFrame, signatures: RowSignatures, bands: StickyBands, expected: Int?) -> Int? {
        let top = bands.header
        let bottom = gray.height - bands.footer
        let maxOffset = bottom - top - configuration.minimumOverlap
        guard maxOffset >= 1 else { return nil }
        guard let expected, expected > 0 else {
            return unambiguous(estimate(signatures, gray, top: top, bottom: bottom, candidates: 1 ... maxOffset, expected: nil))
        }
        let lower = max(1, Int((Double(expected) * (1 - configuration.searchTolerance)).rounded(.down)))
        let upper = min(maxOffset, Int((Double(expected) * (1 + configuration.searchTolerance)).rounded(.up)))
        if lower <= upper, let match = estimate(
            signatures,
            gray,
            top: top,
            bottom: bottom,
            candidates: lower ... upper,
            expected: expected
        ) {
            return match.offset
        }
        // At the end of the content a scroll moves less than asked for.
        guard lower > 1 else { return nil }
        let shorter = estimate(signatures, gray, top: top, bottom: bottom, candidates: 1 ... min(lower - 1, maxOffset), expected: nil)
        return unambiguous(shorter)
    }

    /// The best offset among `candidates`, if it correlates well enough and the overlap really matches.
    private func estimate(
        _ signatures: RowSignatures,
        _ gray: GrayFrame,
        top: Int,
        bottom: Int,
        candidates: ClosedRange<Int>,
        expected: Int?
    ) -> OffsetEstimator.Match? {
        guard let match = OffsetEstimator.bestOffset(
            previous: lastSignatures,
            next: signatures,
            top: top,
            bottom: bottom,
            candidates: candidates,
            expected: expected
        ), match.score >= configuration.minimumScore else {
            return nil
        }
        let overlap = bottom - top - match.offset
        let difference = lastGray.bandDifference(top + match.offset, gray, top, count: overlap)
        return difference <= configuration.maximumDifference ? match : nil
    }

    private func unambiguous(_ match: OffsetEstimator.Match?) -> Int? {
        guard let match, !match.isAmbiguous else { return nil }
        return match.offset
    }

    /// Adds the rows of `frame` that are new: below everything so far and above its footer. Tracking how far the
    /// content scrolled keeps the result exact when the footer estimate changes from one frame to the next.
    private mutating func compose(_ frame: PixelFrame, offset: Int, footer newFooter: Int) -> Step {
        if canvas == nil {
            canvas = StitchCanvas(width: first.width)
            canvas?.append(rows: 0 ..< (first.height - newFooter), of: first)
        }
        scrolled += offset
        footer = newFooter
        let height = canvas?.height ?? 0
        let start = max(0, height - scrolled)
        let end = frame.height - newFooter
        let room = configuration.maxLength - newFooter - height
        if start < end, room > 0 {
            canvas?.append(rows: start ..< min(end, start + room), of: frame)
        }
        if (canvas?.height ?? 0) + newFooter >= configuration.maxLength {
            isComplete = true
            return .limitReached
        }
        return .appended(offset: offset)
    }

    private func oriented(_ frame: PixelFrame) -> PixelFrame {
        direction == .horizontal ? frame.transposed() : frame
    }
}
