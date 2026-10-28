import Accelerate

/// Finds how far content scrolled between two frames: the offset that maximizes the normalized cross-correlation of
/// their row signatures over the overlapping band, computed with vDSP (PLAN §7.3, item 5).
nonisolated enum OffsetEstimator {
    struct Match: Sendable, Equatable {
        /// Rows the content moved up (or left, for transposed frames).
        let offset: Int
        /// Normalized cross-correlation of the overlap, −1…1.
        let score: Double
        /// Another offset more than two rows away scores as well, as repeated table rows do.
        let isAmbiguous: Bool
    }

    /// Scores closer than this to the best count as ties.
    static let tieTolerance = 1e-3

    /// Compares rows `top ..< bottom - offset` of `next` with rows `top + offset ..< bottom` of `previous` for every
    /// offset in `candidates`. Among tied scores the offset closest to `expected` wins, else the smallest.
    static func bestOffset(
        previous: RowSignatures,
        next: RowSignatures,
        top: Int,
        bottom: Int,
        candidates: ClosedRange<Int>,
        expected: Int?
    ) -> Match? {
        let bins = previous.bins
        guard next.bins == bins, next.rows == previous.rows, top >= 0, bottom <= previous.rows else { return nil }
        var scores: [(offset: Int, score: Double)] = []
        previous.values.withUnsafeBufferPointer { earlier in
            next.values.withUnsafeBufferPointer { later in
                for offset in candidates {
                    let count = bottom - top - offset
                    guard offset > 0, count > 0 else { continue }
                    let earlierRows = (top + offset) ..< bottom
                    let laterRows = top ..< (bottom - offset)
                    let x = UnsafeBufferPointer(rebasing: earlier[(earlierRows.lowerBound * bins) ..< (earlierRows.upperBound * bins)])
                    let y = UnsafeBufferPointer(rebasing: later[(laterRows.lowerBound * bins) ..< (laterRows.upperBound * bins)])
                    let score = correlation(
                        count: Double(count * bins),
                        sums: (previous.sum(rows: earlierRows), next.sum(rows: laterRows)),
                        squares: (previous.sumOfSquares(rows: earlierRows), next.sumOfSquares(rows: laterRows)),
                        product: vDSP.dot(x, y)
                    )
                    scores.append((offset, score))
                }
            }
        }
        return pick(scores, expected: expected)
    }

    /// Pearson correlation from sums. Two flat bands (blank space) correlate when their levels agree; a flat band
    /// never correlates with a textured one.
    static func correlation(count: Double, sums: (Double, Double), squares: (Double, Double), product: Double) -> Double {
        let varianceX = max(0, squares.0 - sums.0 * sums.0 / count)
        let varianceY = max(0, squares.1 - sums.1 * sums.1 / count)
        let flatX = varianceX / count < 0.01
        let flatY = varianceY / count < 0.01
        if flatX, flatY {
            return abs(sums.0 - sums.1) / count < 1 ? 1 : 0
        }
        if flatX || flatY {
            return 0
        }
        return (product - sums.0 * sums.1 / count) / (varianceX * varianceY).squareRoot()
    }

    private static func pick(_ scores: [(offset: Int, score: Double)], expected: Int?) -> Match? {
        guard let best = scores.map(\.score).max() else { return nil }
        let ties = scores.filter { $0.score >= best - tieTolerance }
        let chosen: (offset: Int, score: Double)? = if let expected {
            ties.min { abs($0.offset - expected) < abs($1.offset - expected) }
        } else {
            ties.first
        }
        guard let chosen else { return nil }
        let isAmbiguous = ties.contains { abs($0.offset - chosen.offset) > 2 }
        return Match(offset: chosen.offset, score: chosen.score, isAmbiguous: isAmbiguous)
    }
}
