import CoreGraphics
import Foundation
import OrielCore

/// One capture kept in history: a PNG and a thumbnail under `AppPaths.captureHistory`, described in `index.json`.
nonisolated struct HistoryEntry: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let kind: CaptureKind
    /// The captured area, global CoreGraphics points.
    let rect: CGRect
    let scale: CGFloat
    let pixelWidth: Int
    let pixelHeight: Int
    var appName: String?
    var windowTitle: String?
    /// The text OCR found, once indexed. Nil until then; empty when the image has no text.
    var recognizedText: String?

    init(result: CaptureResult) {
        id = result.id
        date = result.date
        kind = result.kind
        rect = result.rect
        scale = result.scale
        pixelWidth = result.image.width
        pixelHeight = result.image.height
        appName = result.appName
        windowTitle = result.windowTitle
    }

    var imageFileName: String {
        "\(id.uuidString).png"
    }

    var thumbnailFileName: String {
        "\(id.uuidString)-thumb.jpg"
    }

    var isIndexed: Bool {
        recognizedText != nil
    }

    /// A short description for the history grid.
    var caption: String {
        let source = appName ?? FilenameTemplate.kindName(kind)
        return "\(source) · \(pixelWidth) × \(pixelHeight)"
    }
}
