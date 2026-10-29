import CoreGraphics
import Foundation
import OrielCore

/// How Capture Text turns the lines OCR read in an area into text (PLAN §17): in reading order, with the line breaks
/// the area shows, a blank line between paragraphs and between columns, a tab between the cells of a table or form,
/// and words that a hyphen at the end of a line split joined again. Pure, so every rule is unit-tested. Whether
/// "search-" and "able" make "searchable" is a question for a dictionary, which the caller asks about
/// `hyphenatedWords`.
///
/// Reading order comes from cutting the area apart where no line crosses: first between columns of prose (at least
/// two lines of 15 characters or more on each side, side by side), else between rows at the widest gap. What cannot be
/// cut further reads as rows, left to right, or right to left in Arabic and Hebrew. Tables and forms therefore read
/// row by row, and newspaper-style columns one after the other.
nonisolated struct TextLayout: Sendable, Equatable {
    /// One line of the result.
    struct Row: Sendable, Equatable {
        var text: String
        /// A blank line comes first: a new paragraph or column.
        var startsParagraph: Bool
    }

    /// The lines, in reading order.
    let rows: [Row]

    /// `blocks` are lines (`OCRMode.fast`), boxes in image pixels with a top-left origin, in any order.
    init(blocks: [OCRBlock]) {
        let lines = blocks.compactMap { block -> Line? in
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, block.boundingBox.width > 0, block.boundingBox.height > 0 else { return nil }
            return Line(text: text, box: block.boundingBox)
        }
        guard !lines.isEmpty else {
            rows = []
            return
        }
        let context = Context(
            lineHeight: Self.median(lines.map(\.box.height)),
            isRightToLeft: Self.isRightToLeft(lines.map(\.text).joined())
        )
        let pieces = Self.arrange(lines, context)
        let threshold = Self.paragraphThreshold(gaps: pieces.compactMap(\.gap), lineHeight: context.lineHeight)
        rows = pieces.enumerated().map { index, piece in
            let startsParagraph = switch piece.separation {
            case .start: false
            case .column: index > 0
            case let .gap(gap): gap > 0 && gap >= threshold
            }
            return Row(text: Self.join(piece.lines), startsParagraph: startsParagraph)
        }
    }

    /// The words a line-end hyphen may have split, such as "searchable" for "search-" and "able …": a letter before
    /// the hyphen and a lowercase letter starting the next line of the same paragraph.
    var hyphenatedWords: Set<String> {
        Set(zip(rows, rows.dropFirst()).compactMap { first, second in
            second.startsParagraph ? nil : Self.splitWord(first.text, second.text)
        })
    }

    /// The text. A word split by a hyphen loses the hyphen when `dictionaryWords` has it ("searchable"), and keeps it
    /// otherwise ("well-known", "10-20", "Jean-Paul"); either way the two lines become one. A soft hyphen always goes.
    func text(dictionaryWords: Set<String> = []) -> String {
        var lines: [Row] = []
        for row in rows {
            if !row.startsParagraph, let last = lines.last, let joined = Self.joinHyphenated(last.text, row.text, words: dictionaryWords) {
                lines[lines.count - 1].text = joined
            } else {
                lines.append(row)
            }
        }
        return lines.enumerated().map { index, row in
            let separator = index == 0 ? "" : row.startsParagraph ? "\n\n" : "\n"
            return separator + row.text
        }.joined()
    }

    // MARK: - Reading order

    private struct Line {
        let text: String
        let box: CGRect
    }

    private struct Context {
        let lineHeight: CGFloat
        let isRightToLeft: Bool
    }

    /// What comes between a piece and the one before it.
    private enum Separation {
        case start
        /// The next column.
        case column
        /// Rows `gap` pixels apart (negative when they overlap).
        case gap(CGFloat)
    }

    /// One row of the result: its lines and what separates it from the row before.
    private struct Piece {
        var lines: [Line]
        var separation: Separation

        var gap: CGFloat? {
            if case let .gap(gap) = separation {
                return gap
            }
            return nil
        }
    }

    private static let hyphens: Set<Character> = ["-", "\u{2010}", "\u{00AD}"]
    /// Lines of prose are at least this long, which the labels of a form are not.
    private static let proseCharacters = 15

    private static func arrange(_ group: [Line], _ context: Context) -> [Piece] {
        if let (first, second) = columns(in: group, context) {
            return arrange(first, context) + starting(arrange(second, context), with: .column)
        }
        if let (top, bottom, gap) = horizontalCut(of: group) {
            return arrange(top, context) + starting(arrange(bottom, context), with: .gap(gap))
        }
        return rows(of: group)
    }

    private static func starting(_ pieces: [Piece], with separation: Separation) -> [Piece] {
        var pieces = pieces
        if !pieces.isEmpty {
            pieces[0].separation = separation
        }
        return pieces
    }

    /// Two columns of prose split by a vertical gap that no line crosses, the widest such gap first; in reading
    /// order, so the right column comes first in a right-to-left script.
    private static func columns(in group: [Line], _ context: Context) -> ([Line], [Line])? {
        guard group.count >= 4 else { return nil }
        let sorted = group.sorted { $0.box.minX < $1.box.minX }
        var reach = sorted[0].box.maxX
        var gutters: [(width: CGFloat, index: Int)] = []
        for index in sorted.indices.dropFirst() {
            let box = sorted[index].box
            if box.minX > reach {
                gutters.append((box.minX - reach, index))
            }
            reach = max(reach, box.maxX)
        }
        for gutter in gutters.sorted(by: { $0.width > $1.width }) where gutter.width >= context.lineHeight / 2 {
            let left = Array(sorted[..<gutter.index])
            let right = Array(sorted[gutter.index...])
            guard isProse(left), isProse(right), sideBySide(left, right) else { continue }
            return context.isRightToLeft ? (right, left) : (left, right)
        }
        return nil
    }

    private static func isProse(_ lines: [Line]) -> Bool {
        lines.count >= 2 && median(lines.map { CGFloat($0.text.count) }) >= CGFloat(proseCharacters)
    }

    /// The two groups share at least half of the shorter one's height.
    private static func sideBySide(_ left: [Line], _ right: [Line]) -> Bool {
        let first = span(of: left)
        let second = span(of: right)
        let overlap = min(first.upperBound, second.upperBound) - max(first.lowerBound, second.lowerBound)
        return overlap >= 0.5 * min(first.upperBound - first.lowerBound, second.upperBound - second.lowerBound)
    }

    private static func span(of lines: [Line]) -> ClosedRange<CGFloat> {
        let top = lines.map(\.box.minY).min() ?? 0
        let bottom = lines.map(\.box.maxY).max() ?? 0
        return top ... max(top, bottom)
    }

    /// The widest horizontal gap that no line crosses: the rows above it and the rows below.
    private static func horizontalCut(of group: [Line]) -> ([Line], [Line], CGFloat)? {
        guard group.count >= 2 else { return nil }
        let sorted = group.sorted { $0.box.minY < $1.box.minY }
        var reach = sorted[0].box.maxY
        var best: (index: Int, gap: CGFloat)?
        for index in sorted.indices.dropFirst() {
            let gap = sorted[index].box.minY - reach
            if gap > 0, gap > (best?.gap ?? 0) {
                best = (index, gap)
            }
            reach = max(reach, sorted[index].box.maxY)
        }
        guard let best else { return nil }
        return (Array(sorted[..<best.index]), Array(sorted[best.index...]), best.gap)
    }

    /// Lines that no gap separates, grouped into rows: a line joins a row when its middle lies above the bottom of
    /// the row's first line.
    private static func rows(of group: [Line]) -> [Piece] {
        let sorted = group.sorted { $0.box.minY < $1.box.minY }
        var rows: [[Line]] = []
        var rowBottom = -CGFloat.infinity
        for line in sorted {
            if !rows.isEmpty, line.box.midY <= rowBottom {
                rows[rows.count - 1].append(line)
            } else {
                rows.append([line])
                rowBottom = line.box.maxY
            }
        }
        return rows.enumerated().map { index, row in
            guard index > 0 else { return Piece(lines: row, separation: .start) }
            let top = row.map(\.box.minY).min() ?? 0
            let bottom = rows[index - 1].map(\.box.maxY).max() ?? 0
            return Piece(lines: row, separation: .gap(top - bottom))
        }
    }

    /// A row's lines in reading order: a tab between pieces farther apart than one and a half line heights (table
    /// cells, a label and its value), a space otherwise.
    private static func join(_ lines: [Line]) -> String {
        let rightToLeft = isRightToLeft(lines.map(\.text).joined())
        let ordered = lines.sorted { rightToLeft ? $0.box.maxX > $1.box.maxX : $0.box.minX < $1.box.minX }
        let height = median(ordered.map(\.box.height))
        var text = ordered.first?.text ?? ""
        for (previous, line) in zip(ordered, ordered.dropFirst()) {
            let gap = rightToLeft ? previous.box.minX - line.box.maxX : line.box.minX - previous.box.maxX
            text += (gap >= 1.5 * height ? "\t" : " ") + line.text
        }
        return text
    }

    /// How far apart two rows must be to start a paragraph: half again the usual gap between lines (the lower
    /// quartile, so a few wide gaps do not raise it) and at least 0.6 line heights. With fewer than three gaps there
    /// is no usual one, and a full line height is the measure.
    private static func paragraphThreshold(gaps: [CGFloat], lineHeight: CGFloat) -> CGFloat {
        let positive = gaps.filter { $0 > 0 }.sorted()
        guard positive.count >= 3 else { return lineHeight }
        let usual = positive[(positive.count - 1) / 4]
        return max(0.6 * lineHeight, 1.5 * usual)
    }

    // MARK: - Hyphens

    /// "searchable" for "… search-" followed by "able …".
    private static func splitWord(_ first: String, _ second: String) -> String? {
        guard let mark = first.last, mark == "-" || mark == "\u{2010}" else { return nil }
        let head = first.dropLast()
        let fragment = String(head.reversed().prefix(while: \.isLetter).reversed())
        let continuation = String(second.prefix(while: \.isLetter))
        guard !fragment.isEmpty, let start = continuation.first, start.isLowercase else { return nil }
        return fragment + continuation
    }

    /// The two lines as one when the first ends in a hyphen right after a letter or digit and the second starts with
    /// one; nil when the line break stays.
    private static func joinHyphenated(_ first: String, _ second: String, words: Set<String>) -> String? {
        guard let mark = first.last, hyphens.contains(mark) else { return nil }
        let head = String(first.dropLast())
        guard let before = head.last, before.isLetter || before.isNumber,
              let start = second.first, start.isLetter || start.isNumber
        else {
            return nil
        }
        if mark == "\u{00AD}" {
            return head + second
        }
        if let word = splitWord(first, second), words.contains(word) {
            return head + second
        }
        return first + second
    }

    // MARK: - Helpers

    private static func median(_ values: [CGFloat]) -> CGFloat {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        return sorted[sorted.count / 2]
    }

    /// More Hebrew or Arabic letters than others.
    private static func isRightToLeft(_ text: String) -> Bool {
        var rightToLeft = 0
        var others = 0
        for scalar in text.unicodeScalars where scalar.properties.isAlphabetic {
            switch scalar.value {
            case 0x0590 ... 0x08FF, 0xFB1D ... 0xFDFF, 0xFE70 ... 0xFEFF: rightToLeft += 1
            default: others += 1
            }
        }
        return rightToLeft > others
    }
}
