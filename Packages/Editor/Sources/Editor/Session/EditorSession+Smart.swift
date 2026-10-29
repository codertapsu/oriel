import CoreGraphics
import Foundation

/// The smart tools' changes (PLAN §17). Each is one undo step, however many items it adds.
extension EditorSession {
    /// Outlines what a smart tool's review would change; an empty list clears the outlines.
    func showSmartPreview(_ boxes: [SmartPreviewBox]) {
        guard boxes != smartPreview else { return }
        smartPreview = boxes
        notify()
    }

    /// Smart Redact: adds the regions and selects them, so their strength can still be changed with the width.
    func applyRedaction(_ regions: [AnnotationItem]) {
        guard !regions.isEmpty else { return }
        commitPendingEdits()
        commit("Smart Redact") { $0.items.append(contentsOf: regions) }
        selection = Set(regions.map(\.id))
        notify()
    }

    /// Simplify: erases each line of text, draws its bar, and tones the rest down by `tone` (nil or 0 leaves the
    /// image's colours alone).
    func applySimplify(_ plan: SimplifyPlan, tone: Double?) {
        guard !plan.bars.isEmpty || tone != nil else { return }
        commitPendingEdits()
        commit("Simplify") { document in
            document.items.append(contentsOf: plan.patches.map(AnnotationItem.patch))
            document.items.append(contentsOf: plan.bars.map(AnnotationItem.bar))
            document.tone = tone.flatMap { $0 > 0 ? min($0, 1) : nil }
        }
        selection = []
        notify()
    }

    /// Changes how much the image is toned down behind the annotations (one undo step per slider drag).
    func setTone(_ tone: Double) {
        commit("Tone Down", coalescing: "tone") { $0.tone = tone > 0.005 ? min(tone, 1) : nil }
    }

    /// Smart Move: fills each object's hole and puts the object on top as a layer of its own, then switches to the
    /// select tool so the objects can be dragged away or deleted straight away.
    func applySmartMove(_ objects: [MovableObject]) {
        guard !objects.isEmpty else { return }
        commitPendingEdits()
        commit("Smart Move") { document in
            document.items.append(contentsOf: objects.map { AnnotationItem.patch($0.patch) })
            document.items.append(contentsOf: objects.map { AnnotationItem.image($0.layer) })
        }
        selectTool(.select)
        selection = []
        notify()
    }
}
