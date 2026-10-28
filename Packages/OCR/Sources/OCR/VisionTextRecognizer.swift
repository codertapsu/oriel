import CoreGraphics
import Foundation
import OrielCore
import Vision

/// On-device OCR with Vision (PLAN §7.6). Needs no permission and never leaves the Mac.
///
/// - `.document` reads paragraphs (including list items and table cells) with `RecognizeDocumentsRequest`, for the
///   translation overlay and history.
/// - `.fast` reads lines with `RecognizeTextRequest` (accurate level, language correction, automatic language), for
///   "Copy Text" and quick translation.
///
/// Boxes are converted once from Vision's normalized bottom-left space to image pixels with a top-left origin.
public struct VisionTextRecognizer: TextRecognizing {
    private static let log = Log.logger("ocr")

    public init() {}

    /// Recognizes the text in `image`. `languages` are BCP 47 hints; hints Vision cannot read are ignored, and an
    /// empty list (or no usable hint) means automatic language detection.
    public func recognize(_ image: CGImage, mode: OCRMode, languages: [String]) async throws -> [OCRBlock] {
        let hints = languages.map(Locale.Language.init(identifier:))
        let regions: [RecognizedRegion]
        let ordering: OCRLayout.Ordering
        switch mode {
        case .document:
            regions = try await Self.paragraphs(in: image, hints: hints)
            ordering = .asRecognized
        case .fast:
            regions = try await Self.lines(in: image, hints: hints)
            ordering = .readingOrder
        }
        try Task.checkCancellation()
        let size = CGSize(width: image.width, height: image.height)
        let blocks = OCRLayout.blocks(from: regions, imageSize: size, ordering: ordering)
        Self.log.debug("OCR (\(mode.rawValue, privacy: .public)) found \(blocks.count) blocks in a \(image.width)×\(image.height) image")
        return blocks
    }

    private static func paragraphs(in image: CGImage, hints: [Locale.Language]) async throws -> [RecognizedRegion] {
        var request = RecognizeDocumentsRequest()
        let usable = matching(hints, in: request.supportedRecognitionLanguages)
        request.textRecognitionOptions.useLanguageCorrection = true
        request.textRecognitionOptions.automaticallyDetectLanguage = usable.isEmpty
        if !usable.isEmpty {
            request.textRecognitionOptions.recognitionLanguages = usable
        }
        var regions: [RecognizedRegion] = []
        for observation in try await request.perform(on: image) {
            collect(observation.document, into: &regions)
        }
        return regions
    }

    /// Paragraphs first (they include the title), then the text of table cells and list items, which `OCRLayout`
    /// drops again when a paragraph already covers it.
    private static func collect(_ container: DocumentObservation.Container, into regions: inout [RecognizedRegion]) {
        regions += container.paragraphs.map(region(from:))
        for table in container.tables {
            for row in table.rows {
                for cell in row {
                    regions += cell.content.paragraphs.map(region(from:))
                }
            }
        }
        for list in container.lists {
            for item in list.items {
                regions += item.content.paragraphs.map(region(from:))
            }
        }
    }

    private static func region(from text: DocumentObservation.Container.Text) -> RecognizedRegion {
        let confidences = text.lines.map(\.confidence)
        let confidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)
        return RecognizedRegion(
            text: text.transcript,
            normalizedBox: text.boundingRegion.boundingBox.cgRect,
            confidence: confidence,
            lineCount: max(1, text.lines.count)
        )
    }

    private static func lines(in image: CGImage, hints: [Locale.Language]) async throws -> [RecognizedRegion] {
        var request = RecognizeTextRequest()
        let usable = matching(hints, in: request.supportedRecognitionLanguages)
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = usable.isEmpty
        if !usable.isEmpty {
            request.recognitionLanguages = usable
        }
        return try await request.perform(on: image).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedRegion(
                text: candidate.string,
                normalizedBox: observation.boundingBox.cgRect,
                confidence: candidate.confidence,
                lineCount: 1
            )
        }
    }

    /// The supported recognition languages that match the hints by language code (and script, when the hint has one),
    /// in hint order and without repeats.
    static func matching(_ hints: [Locale.Language], in supported: [Locale.Language]) -> [Locale.Language] {
        var result: [Locale.Language] = []
        for hint in hints {
            guard let code = hint.languageCode else { continue }
            let match = supported.first { language in
                language.languageCode == code && (hint.script == nil || language.script == hint.script)
            }
            if let match, !result.contains(match) {
                result.append(match)
            }
        }
        return result
    }
}
