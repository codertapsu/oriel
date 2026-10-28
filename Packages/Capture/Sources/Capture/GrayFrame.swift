/// The grey levels of a frame and the comparisons the stitcher makes on them (PLAN §7.3, items 5–7). The rightmost
/// `maskWidth` columns are ignored everywhere, because overlay scrollbars appear there while scrolling.
nonisolated struct GrayFrame: Sendable {
    let width: Int
    let height: Int
    /// One byte per pixel, top row first.
    let values: [UInt8]
    /// The columns compared: all but the masked scrollbar strip.
    let usableWidth: Int

    init(_ frame: PixelFrame, maskWidth: Int) {
        width = frame.width
        height = frame.height
        values = frame.grayscale()
        usableWidth = frame.width > maskWidth * 2 ? frame.width - maskWidth : frame.width
    }

    /// Mean absolute difference between row `row` of `self` and row `otherRow` of `other`.
    func rowDifference(_ row: Int, _ other: Self, _ otherRow: Int) -> Double {
        values.withUnsafeBufferPointer { left in
            other.values.withUnsafeBufferPointer { right in
                var total = 0
                let leftStart = row * width
                let rightStart = otherRow * other.width
                for column in 0 ..< usableWidth {
                    total += abs(Int(left[leftStart + column]) - Int(right[rightStart + column]))
                }
                return Double(total) / Double(max(usableWidth, 1))
            }
        }
    }

    /// Mean absolute difference between rows `start ..< start + count` of `self` and `otherStart ..< otherStart + count`
    /// of `other`, sampling every `step`-th row and column.
    func bandDifference(_ start: Int, _ other: Self, _ otherStart: Int, count: Int, step: Int = 2) -> Double {
        guard count > 0 else { return .infinity }
        return values.withUnsafeBufferPointer { left in
            other.values.withUnsafeBufferPointer { right in
                var total = 0
                var samples = 0
                for offset in stride(from: 0, to: count, by: step) {
                    let leftStart = (start + offset) * width
                    let rightStart = (otherStart + offset) * other.width
                    for column in stride(from: 0, to: usableWidth, by: step) {
                        total += abs(Int(left[leftStart + column]) - Int(right[rightStart + column]))
                        samples += 1
                    }
                }
                return Double(total) / Double(max(samples, 1))
            }
        }
    }

    /// Whether two frames show the same thing, as after a scroll that moved nothing.
    func matches(_ other: Self, tolerance: Double) -> Bool {
        width == other.width && height == other.height && bandDifference(0, other, 0, count: height, step: 1) <= tolerance
    }

    /// Rows at the top and the bottom that are the same in both frames: a sticky header and footer (PLAN §7.3,
    /// item 6). Each band is at most `maxFraction` of the height.
    func stickyBands(comparedWith other: Self, tolerance: Double, maxFraction: Double = 0.4) -> StickyBands {
        let limit = Int(Double(height) * maxFraction)
        var header = 0
        while header < limit, rowDifference(header, other, header) <= tolerance {
            header += 1
        }
        var footer = 0
        while footer < limit, rowDifference(height - 1 - footer, other, height - 1 - footer) <= tolerance {
            footer += 1
        }
        return StickyBands(header: header, footer: footer)
    }
}
