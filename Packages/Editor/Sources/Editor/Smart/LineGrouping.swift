import CoreGraphics

/// Groups recognized lines into blocks of text (a paragraph, a label with its caption), which Smart Move lifts as one
/// object each. Lines join a block when they sit just below its last line, are about as tall, and line up with it.
/// Pure.
nonisolated enum LineGrouping {
    static func blocks(_ lines: [CGRect]) -> [CGRect] {
        var blocks: [(rect: CGRect, last: CGRect)] = []
        for line in lines.map(\.standardized).sorted(by: { ($0.minY, $0.minX) < ($1.minY, $1.minX) }) {
            if let index = blocks.lastIndex(where: { joins(line, after: $0.last) }) {
                blocks[index].rect = blocks[index].rect.union(line)
                blocks[index].last = line
            } else {
                blocks.append((line, line))
            }
        }
        return blocks.map(\.rect)
    }

    /// Whether `line` continues the block whose last line is `previous`.
    static func joins(_ line: CGRect, after previous: CGRect) -> Bool {
        let height = min(line.height, previous.height)
        guard height > 0, max(line.height, previous.height) / height <= 1.6 else { return false }
        let gap = line.minY - previous.maxY
        guard gap >= -height * 0.5, gap <= height * 0.9 else { return false }
        let overlaps = line.minX < previous.maxX && previous.minX < line.maxX
        let leftAligned = abs(line.minX - previous.minX) <= height * 1.5
        return overlaps || leftAligned
    }
}
