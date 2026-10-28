import SharedUI
import UniformTypeIdentifiers

/// The file format of saved captures. It mirrors `ImageFile.Format`, but is nonisolated, so history and drag-out
/// can name and encode files off the main thread.
nonisolated enum CaptureImageFormat: String, CaseIterable, Codable, Sendable, Identifiable {
    case png
    case jpeg
    case heic

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .heic: "HEIC"
        }
    }

    var type: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        }
    }

    var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        case .heic: "heic"
        }
    }

    /// The format a file name extension asks for, when Oriel can write it.
    init?(fileExtension: String) {
        switch fileExtension.lowercased() {
        case "png": self = .png
        case "jpg", "jpeg": self = .jpeg
        case "heic", "heif": self = .heic
        default: return nil
        }
    }

    /// The same format for SharedUI's `ImageFile`, which writes the DPI metadata.
    var imageFileFormat: ImageFile.Format {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        }
    }
}
