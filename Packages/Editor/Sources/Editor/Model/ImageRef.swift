import CoreGraphics
import Foundation

/// The document's base image: the original pixels, never mutated, and how many of them make a point.
///
/// Copying a document copies this reference, not the pixels, so undo snapshots stay small. Two references are
/// equal when they name the same pixels (`id`), which survives a save and reopen.
nonisolated struct ImageRef: Sendable {
    /// Identifies these pixels across saves.
    let id: UUID
    let image: CGImage
    /// Pixels per point (2 for a Retina capture).
    let scale: CGFloat

    init(id: UUID = UUID(), image: CGImage, scale: CGFloat) {
        self.id = id
        self.image = image
        self.scale = max(scale, 0.1)
    }

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    /// The image's size in points, the unit every annotation is measured in.
    var pointSize: CGSize {
        CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
    }

    /// The whole image in image space (points, top-left origin).
    var bounds: CGRect {
        CGRect(origin: .zero, size: pointSize)
    }

    /// Whether some pixels may be transparent, which decides on a checkerboard behind the canvas.
    var hasAlpha: Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: false
        default: true
        }
    }
}

extension ImageRef: Equatable {
    nonisolated static func == (lhs: ImageRef, rhs: ImageRef) -> Bool {
        lhs.id == rhs.id && lhs.scale == rhs.scale && lhs.image.width == rhs.image.width && lhs.image.height == rhs.image.height
    }
}

/// In JSON the reference names the bundle file that holds the pixels. Decoding needs those pixels: pass them as
/// `[fileName: CGImage]` in the decoder's `userInfo` under `ImageRef.imagesKey` (`OrielBundle` does).
extension ImageRef: Codable {
    nonisolated static let imagesKey = CodingUserInfoKey(rawValue: "com.codertapsu.oriel.editor.images")
    nonisolated static let defaultFileName = "original.png"

    private enum CodingKeys: String, CodingKey {
        case id, file, pixelWidth, pixelHeight, scale
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let file = try container.decode(String.self, forKey: .file)
        let width = try container.decode(Int.self, forKey: .pixelWidth)
        let height = try container.decode(Int.self, forKey: .pixelHeight)
        let images = Self.imagesKey.flatMap { decoder.userInfo[$0] as? [String: CGImage] } ?? [:]
        guard let image = images[file] else {
            throw DecodingError.dataCorruptedError(forKey: .file, in: container, debugDescription: "No pixels for \(file).")
        }
        guard image.width == width, image.height == height else {
            throw DecodingError.dataCorruptedError(
                forKey: .file, in: container,
                debugDescription: "\(file) is \(image.width)×\(image.height) px, the document expects \(width)×\(height)."
            )
        }
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            image: image,
            scale: container.decode(CGFloat.self, forKey: .scale)
        )
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(Self.defaultFileName, forKey: .file)
        try container.encode(image.width, forKey: .pixelWidth)
        try container.encode(image.height, forKey: .pixelHeight)
        try container.encode(scale, forKey: .scale)
    }
}
