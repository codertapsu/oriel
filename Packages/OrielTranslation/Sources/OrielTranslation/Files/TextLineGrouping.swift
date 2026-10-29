import CoreGraphics

/// Groups lines into paragraphs by their geometry: a line continues the one above it when the two are about the same
/// height, close together (closer than about three quarters of a line) and in the same column. Used for PDF pages,
/// whose text comes as lines, and for Translate Under Cursor, whose OCR reads lines.
enum TextLineGrouping {
    /// Paragraphs as indexes into `lines`, for lines in reading order (PDFKit's, which follows the page's columns): a
    /// line starts a new paragraph unless it continues the line before it.
    static func sequentialParagraphs(_ lines: [TextLine]) -> [[Int]] {
        var paragraphs: [[Int]] = []
        for index in lines.indices {
            if index > 0, continues(lines[index - 1].box, with: lines[index].box), !paragraphs.isEmpty {
                paragraphs[paragraphs.count - 1].append(index)
            } else {
                paragraphs.append([index])
            }
        }
        return paragraphs
    }

    /// Paragraphs as indexes into `lines`, for lines in any order (OCR), each top to bottom: every line is joined to
    /// the nearest line below it in its column when that one continues it.
    static func geometricParagraphs(_ lines: [TextLine]) -> [[Int]] {
        var parent = Array(lines.indices)
        func root(_ index: Int) -> Int {
            var index = index
            while parent[index] != index {
                parent[index] = parent[parent[index]]
                index = parent[index]
            }
            return index
        }
        for upper in lines.indices {
            let box = lines[upper].box
            let below = lines.indices
                .filter { $0 != upper && lines[$0].box.minY >= box.midY && overlapsHorizontally(box, lines[$0].box) }
                .min { lines[$0].box.minY < lines[$1].box.minY }
            if let below, continues(box, with: lines[below].box) {
                parent[root(below)] = root(upper)
            }
        }
        var groups: [Int: [Int]] = [:]
        for index in lines.indices {
            groups[root(index), default: []].append(index)
        }
        return groups.values
            .map { $0.sorted { (lines[$0].box.minY, lines[$0].box.minX) < (lines[$1].box.minY, lines[$1].box.minX) } }
            .sorted { (lines[$0[0]].box.minY, lines[$0[0]].box.minX) < (lines[$1[0]].box.minY, lines[$1[0]].box.minX) }
    }

    /// Whether `lower` continues the paragraph of `upper`, the line above it.
    static func continues(_ upper: CGRect, with lower: CGRect) -> Bool {
        let height = min(upper.height, lower.height)
        guard height > 0, height / max(upper.height, lower.height) >= 0.6 else { return false }
        let gap = lower.minY - upper.maxY
        guard gap >= -height * 0.5, gap <= height * 0.75 else { return false }
        let alignedLeft = abs(lower.minX - upper.minX) <= height * 2
        return alignedLeft || overlapsHorizontally(upper, lower)
    }

    /// The two overlap by at least a third of the narrower one.
    static func overlapsHorizontally(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let overlap = min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX)
        return overlap > min(lhs.width, rhs.width) / 3
    }
}
