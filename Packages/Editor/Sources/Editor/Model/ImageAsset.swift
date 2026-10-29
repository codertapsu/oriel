import CoreGraphics
import Foundation

/// Pixels a document carries besides its base image: an object Smart Move lifted out, the background it filled the
/// hole with, or a background picture. Like `ImageRef`, copying it copies a reference, and two assets are equal when
/// they name the same pixels.
///
/// In a saved document an asset is a PNG in the bundle's `images` folder, named by its id.
nonisolated struct ImageAsset: Sendable {
    let id: UUID
    let image: CGImage

    init(id: UUID = UUID(), image: CGImage) {
        self.id = id
        self.image = image
    }

    /// The asset's path inside an `.oriel` bundle.
    var fileName: String {
        "\(Self.folderName)/\(id.uuidString.lowercased()).png"
    }

    var pixelSize: CGSize {
        CGSize(width: image.width, height: image.height)
    }

    /// The folder of an `.oriel` bundle that holds the assets.
    static let folderName = "images"
}

extension ImageAsset: Hashable {
    nonisolated static func == (lhs: ImageAsset, rhs: ImageAsset) -> Bool {
        lhs.id == rhs.id && lhs.image.width == rhs.image.width && lhs.image.height == rhs.image.height
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Encoded as the file that holds the pixels; decoding takes them from the decoder's `userInfo` under
/// `ImageRef.imagesKey`, as the base image does.
extension ImageAsset: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, file, pixelWidth, pixelHeight
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let file = try container.decode(String.self, forKey: .file)
        let width = try container.decode(Int.self, forKey: .pixelWidth)
        let height = try container.decode(Int.self, forKey: .pixelHeight)
        let images = ImageRef.imagesKey.flatMap { decoder.userInfo[$0] as? [String: CGImage] } ?? [:]
        guard let image = images[file] else {
            throw DecodingError.dataCorruptedError(forKey: .file, in: container, debugDescription: "No pixels for \(file).")
        }
        guard image.width == width, image.height == height else {
            throw DecodingError.dataCorruptedError(
                forKey: .file, in: container,
                debugDescription: "\(file) is \(image.width)×\(image.height) px, the document expects \(width)×\(height)."
            )
        }
        try self.init(id: container.decode(UUID.self, forKey: .id), image: image)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .file)
        try container.encode(image.width, forKey: .pixelWidth)
        try container.encode(image.height, forKey: .pixelHeight)
    }
}
