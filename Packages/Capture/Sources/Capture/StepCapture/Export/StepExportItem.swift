import CoreGraphics
import Foundation

/// One step as the exporters see it: a snapshot taken on the main actor and read off it, with the image still on disk
/// so that a long sequence is never in memory at once.
nonisolated struct StepExportItem: Sendable, Equatable {
    let number: Int
    /// The title, or "Step 3".
    let heading: String
    let note: String
    let imageURL: URL
    let pixelWidth: Int
    let pixelHeight: Int
    let scale: CGFloat
    /// Pixels, top-left origin.
    let click: CGPoint?

    init(step: Step, number: Int) {
        self.number = number
        heading = step.heading(number: number)
        note = step.note.trimmingCharacters(in: .whitespacesAndNewlines)
        imageURL = step.imageURL
        pixelWidth = step.pixelWidth
        pixelHeight = step.pixelHeight
        scale = max(step.scale, 1)
        click = step.click
    }

    /// The image's size in points.
    var pointSize: CGSize {
        CGSize(width: CGFloat(pixelWidth) / scale, height: CGFloat(pixelHeight) / scale)
    }
}
