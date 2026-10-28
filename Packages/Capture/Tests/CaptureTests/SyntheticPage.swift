@testable import Capture

/// A deterministic "document" for the stitcher tests: lines of noisy grey rows (like text) separated by blank rows,
/// optionally with a block that repeats, like the rows of a table.
struct SyntheticPage {
    let width: Int
    private(set) var rows: [[UInt8]] = []

    /// `repeating` replaces those rows with copies of one 40-row block.
    init(width: Int, height: Int, seed: UInt64, repeating: Range<Int>? = nil) {
        self.width = width
        var generator = SplitMix(seed: seed)
        while rows.count < height {
            let lineHeight = 8 + Int(generator.next() % 12)
            for _ in 0 ..< lineHeight {
                rows.append((0 ..< width).map { _ in UInt8(truncatingIfNeeded: generator.next() >> 56) })
            }
            let gap = 2 + Int(generator.next() % 5)
            rows.append(contentsOf: Array(repeating: Array(repeating: 250, count: width), count: gap))
        }
        rows = Array(rows.prefix(height))
        if let repeating {
            let block = Array(rows[repeating.lowerBound ..< repeating.lowerBound + 40])
            for row in repeating {
                rows[row] = block[(row - repeating.lowerBound) % 40]
            }
        }
    }

    /// Rows `range` as an RGBA frame.
    func frame(_ range: Range<Int>) -> PixelFrame {
        Self.frame(Array(rows[range]))
    }

    /// The rows of a viewport scrolled to `position`, `height` tall.
    func viewport(at position: Int, height: Int) -> PixelFrame {
        frame(position ..< position + height)
    }

    static func frame(_ rows: [[UInt8]]) -> PixelFrame {
        let width = rows.first?.count ?? 0
        var pixels: [UInt8] = []
        pixels.reserveCapacity(rows.count * width * 4)
        for row in rows {
            for value in row {
                pixels.append(contentsOf: [value, value, value, 255])
            }
        }
        return PixelFrame(width: width, height: rows.count, pixels: pixels)
    }

    /// A small, seedable generator, so every run sees the same page.
    struct SplitMix {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }
}
