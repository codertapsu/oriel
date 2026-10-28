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
    /// Z-ordered: later items draw on top (but see `AnnotationItem.isImageEffect`).
    var items: [AnnotationItem]

    init(
        base: ImageRef,
        crop: CGRect? = nil,
        canvasPadding: Padding? = nil,
        background: BackgroundStyle? = nil,
        items: [AnnotationItem] = []
    ) {
        self.base = base
        self.crop = crop
        self.canvasPadding = canvasPadding
        self.background = background
        self.items = items
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

    /// The number the next step marker gets: one more than the highest so far.
    var nextCounterNumber: Int {
        let numbers = items.compactMap { item -> Int? in
            if case let .counter(counter) = item {
                return counter.number
            }
            return nil
        }
        return (numbers.max() ?? 0) + 1
    }

    /// Replaces the item with the same id, if there is one.
    mutating func replace(_ item: AnnotationItem) {
        guard let index = index(of: item.id) else { return }
        items[index] = item
    }

    /// Removes the items and closes the gaps in the step numbers, so the steps left read 1, 2, 3…
    mutating func remove(_ ids: Set<UUID>) {
        let hadCounters = items.contains { ids.contains($0.id) && $0.kind == .counter }
        items.removeAll { ids.contains($0.id) }
        if hadCounters {
            renumberCounters()
        }
    }

    /// Numbers the step markers 1…n in their current order (number first, then z-order).
    mutating func renumberCounters() {
        let order = items.indices
            .compactMap { index -> (index: Int, number: Int)? in
                if case let .counter(counter) = items[index] {
                    return (index, counter.number)
                }
                return nil
            }
            .sorted { $0.number == $1.number ? $0.index < $1.index : $0.number < $1.number }
        for (position, entry) in order.enumerated() {
            if case var .counter(counter) = items[entry.index] {
                counter.number = position + 1
                items[entry.index] = .counter(counter)
            }
        }
    }
}
