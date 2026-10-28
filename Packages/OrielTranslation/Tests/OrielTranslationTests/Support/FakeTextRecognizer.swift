import CoreGraphics
import OrielCore
import Synchronization

/// OCR that returns canned blocks and remembers the language hints it was given.
final class FakeTextRecognizer: TextRecognizing {
    let blocks: [OCRBlock]
    private let hints = Mutex<[[String]]>([])

    init(_ blocks: [OCRBlock]) {
        self.blocks = blocks
    }

    var receivedHints: [[String]] {
        hints.withLock { $0 }
    }

    func recognize(_: CGImage, mode _: OCRMode, languages: [String]) async throws -> [OCRBlock] {
        hints.withLock { $0.append(languages) }
        return blocks
    }
}
