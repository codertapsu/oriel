import CoreGraphics
import Foundation
import OrielCore

/// Turns Vision's regions into numbered `OCRBlock`s: converts boxes to pixels, drops empty and duplicate regions
/// (a table cell that the document's paragraphs already contain), orders them, numbers them from 1 and detects
/// each block's language.
enum OCRLayout {
    enum Ordering {
        /// Keep Vision's order. `RecognizeDocumentsRequest` already reads multi-column layouts in reading order.
        case asRecognized
        /// Rows top to bottom, left to right within a row. For `RecognizeTextRequest` lines.
        case readingOrder
    }

    private struct Candidate {
        let region: RecognizedRegion
        let text: String
        let box: CGRect
    }

    static func blocks(from regions: [RecognizedRegion], imageSize: CGSize, ordering: Ordering) -> [OCRBlock] {
        var kept: [Candidate] = []
        for region in regions {
            let text = region.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let box = OCRGeometry.pixelRect(fromNormalized: region.normalizedBox, imageSize: imageSize)
            guard !text.isEmpty, box.width > 0, box.height > 0 else { continue }
            let candidate = Candidate(region: region, text: text, box: box)
            guard !kept.contains(where: { isDuplicate(candidate, of: $0) }) else { continue }
            kept.append(candidate)
        }
        let order = switch ordering {
        case .asRecognized: Array(kept.indices)
        case .readingOrder: readingOrder(kept.map(\.box))
        }
        let languages = LanguageDetector.languageCodes(of: order.map { kept[$0].text })
        return order.enumerated().map { position, index in
            let candidate = kept[index]
            return OCRBlock(
                id: position + 1,
                text: candidate.text,
                boundingBox: candidate.box,
                confidence: candidate.region.confidence,
                lineCount: max(1, candidate.region.lineCount),
                language: languages[position]
            )
        }
    }

    /// Indexes of `boxes` (top-left origin) in reading order: a box whose vertical middle lies above the bottom of
    /// the first box of the current row joins that row; rows are read left to right.
    static func readingOrder(_ boxes: [CGRect]) -> [Int] {
        let byTop = boxes.indices.sorted { boxes[$0].minY < boxes[$1].minY }
        var rows: [[Int]] = []
        var rowBottom = -CGFloat.infinity
        for index in byTop {
            let box = boxes[index]
            if !rows.isEmpty, box.midY <= rowBottom {
                rows[rows.count - 1].append(index)
            } else {
                rows.append([index])
                rowBottom = box.maxY
            }
        }
        return rows.flatMap { row in row.sorted { boxes[$0].minX < boxes[$1].minX } }
    }

    /// A region repeats one we already have when it lies (almost) entirely inside it and its text is part of it.
    private static func isDuplicate(_ candidate: Candidate, of existing: Candidate) -> Bool {
        let overlap = candidate.box.intersection(existing.box)
        guard !overlap.isNull else { return false }
        let area = candidate.box.width * candidate.box.height
        guard area > 0, overlap.width * overlap.height >= area * 0.8 else { return false }
        return collapsed(existing.text).contains(collapsed(candidate.text))
    }

    private static func collapsed(_ text: String) -> String {
        text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
