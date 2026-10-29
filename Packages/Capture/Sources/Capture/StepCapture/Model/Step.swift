import CoreGraphics
import Foundation
import OrielCore

/// One step of a Step Capture sequence (PLAN §17): a capture, kept as a PNG in the sequence's folder, with the title
/// and note the user gives it and, when Mark Clicks was on, where they clicked last before taking it.
nonisolated struct Step: Sendable, Equatable, Identifiable {
    let id: UUID
    /// The PNG. A retake or a dropped image writes a new file, so Undo can bring the old one back.
    var imageURL: URL
    var pixelWidth: Int
    var pixelHeight: Int
    /// Pixels per point of the display it came from.
    var scale: CGFloat
    var title = ""
    var note = ""
    /// The click to mark, in the image's pixels with a top-left origin; nil when there is none to show.
    var click: CGPoint?
    var kind: CaptureKind
    var appName: String?
    var windowTitle: String?
    var date: Date

    /// The image's size in points, which is what it is shown at.
    var pointSize: CGSize {
        CGSize(width: CGFloat(pixelWidth) / max(scale, 1), height: CGFloat(pixelHeight) / max(scale, 1))
    }

    /// The title, or "Step 3" while there is none.
    func heading(number: Int) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Step \(number)" : trimmed
    }

    /// The capture mode that takes this step again.
    var retakeMode: CaptureMode {
        switch kind {
        case .area, .imported: .area
        case .window: .window
        case .screen: .screen
        case .scrolling: .scrolling
        }
    }
}

nonisolated extension Step {
    /// A new step from a capture whose PNG is (or is being) written to `imageURL`.
    init(result: CaptureResult, imageURL: URL, click: CGPoint?) {
        self.init(
            id: UUID(),
            imageURL: imageURL,
            pixelWidth: result.image.width,
            pixelHeight: result.image.height,
            scale: max(result.scale, 1),
            click: click,
            kind: result.kind,
            appName: result.appName,
            windowTitle: result.windowTitle,
            date: result.date
        )
    }
}
