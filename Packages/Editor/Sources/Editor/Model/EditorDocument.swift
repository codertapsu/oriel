import CoreGraphics
import Foundation

/// Everything an editor window edits (PLAN §7.5). A small value type, so undo keeps whole snapshots.
///
/// Coordinates are in image space: points from the top-left corner of the uncropped base image, y down. Crop and
/// padding never move annotations; they only change which part of that space becomes the canvas.
nonisolated struct EditorDocument: Codable, Sendable, Equatable {
    /// The original pixels, never mutated.
    var base: ImageRef
    /// The part of the base image to keep, non-destructively. Nil keeps all of it.
    var crop: CGRect?
    /// Space around the image, filled by `background`.
    var canvasPadding: Padding?
    var background: BackgroundStyle?
    /// Z-ordered: later items draw on top (but see `AnnotationItem.isImageLayer`).
    var items: [AnnotationItem]
    /// How much the image is washed out behind the annotations (0…1), Simplify's "tone down". Nil leaves it as is.
    var tone: Double?

    init(
        base: ImageRef,
        crop: CGRect? = nil,
        canvasPadding: Padding? = nil,
        background: BackgroundStyle? = nil,
        items: [AnnotationItem] = [],
        tone: Double? = nil
    ) {
        self.base = base
        self.crop = crop
        self.canvasPadding = canvasPadding
        self.background = background
        self.items = items
        self.tone = tone
    }

    /// The part of the base image the canvas shows: the crop clamped to the image, or the whole image.
    var visibleImageRect: CGRect {
        guard let crop else { return base.bounds }
        let clamped = crop.standardized.intersection(base.bounds)
        return clamped.isNull || clamped.width <= 0 || clamped.height <= 0 ? base.bounds : clamped
    }

    func item(withID id: UUID) -> AnnotationItem? {
        items.first { $0.id == id }
    }

    func index(of id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    /// The pixels the document carries besides the base image, each once: a saved bundle keeps them as files.
    var assets: [ImageAsset] {
        var seen = Set<UUID>()
        var assets: [ImageAsset] = []
        let candidates = [background?.image?.asset] + items.map(\.asset)
        for case let asset? in candidates where seen.insert(asset.id).inserted {
            assets.append(asset)
        }
        return assets
    }

    // MARK: - Steps

    /// The step markers with their index in `items`.
    private var counters: [(index: Int, counter: Counter)] {
        items.indices.compactMap { index in
            if case let .counter(counter) = items[index] {
                return (index, counter)
            }
            return nil
        }
    }

    /// The sequence the next step joins unless the numbering restarts: the newest one.
    var latestStepSequence: Int {
        counters.map(\.counter.sequence).max() ?? 0
    }

    /// The number the next step in `sequence` gets: one more than its highest so far, or 1.
    func nextStepNumber(inSequence sequence: Int) -> Int {
        let numbers = counters.filter { $0.counter.sequence == sequence }.map(\.counter.number)
        return (numbers.max() ?? 0) + 1
    }

    /// The number the next step marker gets: one more than the highest in the newest sequence.
    var nextCounterNumber: Int {
        nextStepNumber(inSequence: latestStepSequence)
    }

    /// Replaces the item with the same id, if there is one.
    mutating func replace(_ item: AnnotationItem) {
        guard let index = index(of: item.id) else { return }
        items[index] = item
    }

    /// Removes the items and closes the gaps in the step numbers, so each sequence left reads on from where it
    /// started (1, 2, 3…, or 5, 6, 7… for one that started at 5).
    mutating func remove(_ ids: Set<UUID>) {
        let affected = Set(counters.filter { ids.contains($0.counter.id) }.map(\.counter.sequence))
        var starts: [Int: Int] = [:]
        for (_, counter) in counters where affected.contains(counter.sequence) {
            starts[counter.sequence] = min(starts[counter.sequence] ?? counter.number, counter.number)
        }
        items.removeAll { ids.contains($0.id) }
        for (sequence, start) in starts {
            renumber(sequence: sequence, from: start)
        }
    }

    /// Numbers every sequence's markers consecutively from its lowest number, in their current order (number first,
    /// then z-order).
    mutating func renumberCounters() {
        var starts: [Int: Int] = [:]
        for (_, counter) in counters {
            starts[counter.sequence] = min(starts[counter.sequence] ?? counter.number, counter.number)
        }
        for (sequence, start) in starts {
            renumber(sequence: sequence, from: start)
        }
    }

    private mutating func renumber(sequence: Int, from start: Int) {
        let order = counters
            .filter { $0.counter.sequence == sequence }
            .sorted { $0.counter.number == $1.counter.number ? $0.index < $1.index : $0.counter.number < $1.counter.number }
        for (position, entry) in order.enumerated() {
            var counter = entry.counter
            counter.number = start + position
            items[entry.index] = .counter(counter)
        }
    }
}
