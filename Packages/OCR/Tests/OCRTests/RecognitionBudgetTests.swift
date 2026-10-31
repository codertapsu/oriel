import Foundation
@testable import OCR
import OrielCore
import Testing

/// OCR of a 1,000 × 600 px screenful with accurate recognition stays under 400 ms on Apple silicon (PLAN §9). A
/// process's first request loads Vision's models; the budget is for the requests after it (the median of five), and
/// both are printed.
struct RecognitionBudgetTests {
    private static let budget = Duration.milliseconds(400)

    @Test(.enabled(if: HardwareInfo.architecture == "arm64", "the budget is for Apple silicon"), arguments: [OCRMode.fast, .document])
    func aScreenfulIsReadInsideTheBudget(_ mode: OCRMode) async throws {
        let image = try TextImage.screenful()
        let recognizer = VisionTextRecognizer()
        let clock = ContinuousClock()
        var blocks: [OCRBlock] = []
        let first = try await clock.measure {
            blocks = try await recognizer.recognize(image, mode: mode, languages: ["en"])
        }
        #expect(blocks.contains { $0.text.contains("Clean Up checks a folder") })
        var runs: [Duration] = []
        for _ in 0 ..< 5 {
            try await runs.append(clock.measure { _ = try await recognizer.recognize(image, mode: mode, languages: ["en"]) })
        }
        let median = runs.sorted()[runs.count / 2]
        print("OCR \(mode.rawValue), 1000×600 px, \(blocks.count) blocks: first \(first), median \(median)")
        #expect(median < Self.budget, "median \(median)")
    }
}
