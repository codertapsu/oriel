import CoreGraphics
import OrielCore

/// OCR that holds every call until the test releases it, and says when it was called: a test can stop a job while a
/// scanned page is being read.
final class GatedTextRecognizer: TextRecognizing {
    let blocks: [OCRBlock]
    private let gate = AsyncStream<Void>.makeStream()
    private let calls = AsyncStream<Void>.makeStream()

    init(_ blocks: [OCRBlock]) {
        self.blocks = blocks
    }

    /// Ends once the recognizer has been called.
    func waitForCall() async {
        for await _ in calls.stream {
            return
        }
    }

    /// Lets one call through, now or when it comes.
    func release() {
        gate.continuation.yield()
    }

    func recognize(_: CGImage, mode _: OCRMode, languages _: [String]) async throws -> [OCRBlock] {
        calls.continuation.yield()
        for await _ in gate.stream {
            break
        }
        return blocks
    }
}
