import CoreGraphics
import Foundation
import OrielCore

/// Reads the text in kept images, one at a time at utility priority, so that images can be found by it, as capture
/// history does.
final class ClipboardTextIndexer {
    /// Called after each image has been read.
    var onIndexed: (() -> Void)?

    private let store: ClipboardStore
    private let recognizer: any TextRecognizing
    private var task: Task<Void, Never>?
    private var runsAgain = false

    init(store: ClipboardStore, recognizer: any TextRecognizing) {
        self.store = store
        self.recognizer = recognizer
    }

    /// Starts reading unless a run is going, which then looks again once it is done.
    func run() {
        guard task == nil else {
            runsAgain = true
            return
        }
        let store = store
        let recognizer = recognizer
        task = Task.detached(priority: .utility) { [weak self] in
            var tried: Set<UUID> = []
            while !Task.isCancelled, let item = await store.unindexedImages().first(where: { !tried.contains($0.id) }) {
                tried.insert(item.id)
                var text = ""
                if let image = store.image(of: item.id, maxPixels: 4096) {
                    let blocks = await (try? recognizer.recognize(image, mode: .document, languages: [])) ?? []
                    text = blocks.map(\.text).joined(separator: "\n")
                }
                try? await store.setRecognizedText(text, for: item.id)
                await self?.indexed()
            }
            await self?.finished()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        runsAgain = false
    }

    private func indexed() {
        onIndexed?()
    }

    private func finished() {
        task = nil
        if runsAgain {
            runsAgain = false
            run()
        }
    }
}
