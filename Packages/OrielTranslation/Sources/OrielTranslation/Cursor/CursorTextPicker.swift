import CoreGraphics
import OrielCore

/// Finds the text under the pointer in what OCR read around it (PLAN §17): the line under the point, or the
/// paragraph that line belongs to, and whether that text runs past the captured area so a larger one should be read.
/// Pure, and in global points with a top-left origin.
enum CursorTextPicker {
    struct Pick: Equatable, Sendable {
        let text: String
        /// The union of the picked lines' boxes.
        let region: CGRect
        /// The picked lines, top to bottom.
        let lines: [TextLine]
    }

    /// OCR lines (pixels of the image of `captureRect`) in global points.
    static func lines(from blocks: [OCRBlock], imageWidth: Int, captureRect: CGRect) -> [TextLine] {
        guard captureRect.width > 0, imageWidth > 0 else { return [] }
        let scale = CGFloat(imageWidth) / captureRect.width
        return blocks.compactMap { block in
            let text = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let box = block.boundingBox
            return TextLine(
                text: text,
                box: CGRect(
                    x: captureRect.minX + box.minX / scale,
                    y: captureRect.minY + box.minY / scale,
                    width: box.width / scale,
                    height: box.height / scale
                )
            )
        }
    }

    /// The index of the line under `point`: its box widened by a few points (and a quarter of its height above and
    /// below) contains the point; the smallest such line wins.
    static func lineIndex(at point: CGPoint, in lines: [TextLine]) -> Int? {
        lines.indices
            .filter { index in
                let box = lines[index].box
                return box.insetBy(dx: -4, dy: -max(2, box.height * 0.25)).contains(point)
            }
            .min { lines[$0].box.width * lines[$0].box.height < lines[$1].box.width * lines[$1].box.height }
    }

    /// The line under `point`, or its paragraph; nil when the point is not on text.
    static func pick(at point: CGPoint, in lines: [TextLine], unit: CursorTextUnit) -> Pick? {
        guard let index = lineIndex(at: point, in: lines) else { return nil }
        let picked: [TextLine]
        switch unit {
        case .line:
            picked = [lines[index]]
        case .paragraph:
            let paragraph = TextLineGrouping.geometricParagraphs(lines).first { $0.contains(index) } ?? [index]
            picked = paragraph.map { lines[$0] }
        }
        let region = picked.dropFirst().reduce(picked[0].box) { $0.union($1.box) }
        return Pick(text: LineJoiner.join(picked.map(\.text)), region: region, lines: picked)
    }

    /// A larger area to read when the picked text touches an edge of `capture` that is not the screen's edge, so it
    /// may go on beyond it: wider for a cut-off line, taller for a paragraph that may continue above or below. Nil when
    /// the text lies within the capture. One step, up to `maximumSize`.
    static func grownRect(
        for pick: Pick,
        capture: CGRect,
        screen: CGRect,
        unit: CursorTextUnit,
        maximumSize: CGSize = CGSize(width: 1600, height: 640)
    ) -> CGRect? {
        let lineHeight = pick.lines.map(\.box.height).max() ?? 16
        let edge: CGFloat = 3
        let touchesLeft = pick.region.minX <= capture.minX + edge && capture.minX > screen.minX
        let touchesRight = pick.region.maxX >= capture.maxX - edge && capture.maxX < screen.maxX
        let vertical = unit == .paragraph
        let touchesTop = vertical && pick.region.minY <= capture.minY + lineHeight * 0.6 && capture.minY > screen.minY
        let touchesBottom = vertical && pick.region.maxY >= capture.maxY - lineHeight * 0.6 && capture.maxY < screen.maxY
        guard touchesLeft || touchesRight || touchesTop || touchesBottom else { return nil }
        var grown = capture
        let wider = max(0, maximumSize.width - capture.width) / CGFloat((touchesLeft ? 1 : 0) + (touchesRight ? 1 : 0)).nonZero
        let taller = min(
            lineHeight * 8,
            max(0, maximumSize.height - capture.height) / CGFloat((touchesTop ? 1 : 0) + (touchesBottom ? 1 : 0)).nonZero
        )
        if touchesLeft {
            grown.origin.x -= wider
            grown.size.width += wider
        }
        if touchesRight {
            grown.size.width += wider
        }
        if touchesTop {
            grown.origin.y -= taller
            grown.size.height += taller
        }
        if touchesBottom {
            grown.size.height += taller
        }
        let clipped = grown.intersection(screen).integral
        return clipped.isNull || clipped.equalTo(capture.integral) ? nil : clipped
    }
}

private extension CGFloat {
    /// 1 instead of 0, for dividing a length between the edges that grow.
    var nonZero: CGFloat {
        self == 0 ? 1 : self
    }
}
