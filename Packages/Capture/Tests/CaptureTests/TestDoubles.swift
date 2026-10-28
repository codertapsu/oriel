@testable import Capture
import CoreGraphics
import Foundation
import OrielCore

/// Records what Capture hands to the app.
final class RecordingActions: CaptureActionHandling {
    private(set) var annotated: [UUID] = []
    private(set) var translated: [UUID] = []
    private(set) var uploaded: [UUID] = []

    func annotate(_ capture: CaptureResult) {
        annotated.append(capture.id)
    }

    func translate(_ capture: CaptureResult) {
        translated.append(capture.id)
    }

    func upload(_ capture: CaptureResult) {
        uploaded.append(capture.id)
    }
}

/// OCR that "reads" a fixed text.
struct FixedTextRecognizer: TextRecognizing {
    let text: String

    func recognize(_: CGImage, mode _: OCRMode, languages _: [String]) async throws -> [OCRBlock] {
        [OCRBlock(id: 0, text: text, boundingBox: .zero, confidence: 1)]
    }
}
