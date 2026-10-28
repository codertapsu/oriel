import SharedUI
import UniformTypeIdentifiers

/// The file formats the editor exports to (⌘E, drag-out).
nonisolated enum EditorExportFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case png
    case jpeg
    case heic
    case pdf

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .heic: "HEIC"
        case .pdf: "PDF"
        }
    }

    var contentType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .pdf: .pdf
        }
    }

    /// The same extensions SharedUI's `ImageFile.Format` writes.
    var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        case .heic: "heic"
        case .pdf: "pdf"
        }
    }

    /// The ImageIO format for bitmap formats; nil for PDF, which the renderer writes as vectors.
    var imageFormat: ImageFile.Format? {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .pdf: nil
        }
    }

    /// JPEG has no alpha channel, so transparent areas are flattened onto white instead of turning black.
    var needsMatte: Bool {
        self == .jpeg
    }
}
