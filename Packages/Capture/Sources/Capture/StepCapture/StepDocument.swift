import CoreGraphics
import Foundation
import OrielCore

/// One finished step sequence, as its window edits it (PLAN §17): the steps, their images, and whether anything
/// changed since the last export, so closing the window can ask first. The window registers undo with snapshots of
/// `sequence`; images stay on disk until the document is discarded, so an undone delete or retake gets them back.
final class StepDocument {
    private(set) var sequence: StepSequence
    let images: StepImages
    /// When the first step was taken.
    let date: Date
    /// The steps or their order changed (not their text, which is edited in place).
    var onChange: (() -> Void)?
    /// Exported since the last change.
    private(set) var isExported = false

    init(sequence: StepSequence, images: StepImages, date: Date) {
        self.sequence = sequence
        self.images = images
        self.date = date
    }

    var title: String {
        get { sequence.title }
        set {
            sequence.title = newValue
            isExported = false
        }
    }

    /// "5 steps · 29 October 2026".
    var subtitle: String {
        StepExporter.subtitle(count: sequence.count, date: date)
    }

    func thumbnail(of step: Step) -> CGImage? {
        images.thumbnails[step.imageURL]
    }

    func image(of step: Step) async -> CGImage? {
        await images.image(at: step.imageURL)
    }

    /// Puts back an earlier state, for Undo and Redo.
    func restore(_ snapshot: StepSequence) {
        sequence = snapshot
        changed()
    }

    func setTitle(_ title: String, of id: UUID) {
        sequence.update(id) { $0.title = title }
        isExported = false
    }

    func setNote(_ note: String, of id: UUID) {
        sequence.update(id) { $0.note = note }
        isExported = false
    }

    func removeClick(of id: UUID) {
        sequence.update(id) { $0.click = nil }
        changed()
    }

    func remove(_ ids: Set<UUID>) {
        sequence.remove(ids)
        changed()
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        sequence.move(fromOffsets: offsets, toOffset: destination)
        changed()
    }

    /// A retake, or an image dropped or pasted on the step: a new file, and no click marker, which belonged to the
    /// old image.
    func replaceImage(of id: UUID, with image: CGImage, scale: CGFloat) {
        let url = images.add(image, scale: scale)
        sequence.update(id) { step in
            step.imageURL = url
            step.pixelWidth = image.width
            step.pixelHeight = image.height
            step.scale = max(scale, 1)
            step.click = nil
        }
        changed()
    }

    /// Adds a capture at the end (Add Step in the window) and returns the new step.
    @discardableResult
    func append(_ result: CaptureResult) -> Step {
        let step = Step(result: result, imageURL: images.add(result.image, scale: result.scale), click: nil)
        sequence.append(step)
        changed()
        return step
    }

    /// Every step as the exporters take it, once every image is on disk.
    func exportItems() async -> [StepExportItem] {
        await images.flush()
        return sequence.steps.enumerated().map { StepExportItem(step: $1, number: $0 + 1) }
    }

    func markExported() {
        isExported = true
    }

    /// Deletes the images; the document is finished with.
    func discard() {
        images.discard()
    }

    private func changed() {
        isExported = false
        onChange?()
    }
}
