import CoreGraphics
import Foundation
import ImageIO
import OrielCore
import SharedUI
import UniformTypeIdentifiers

/// The editable `.oriel` document: a package directory with `document.json` (the document, annotations and all),
/// `original.png` (the untouched base image, lossless) and, from format version 2, an `images` folder with the
/// pixels of lifted objects, filled holes and background pictures, one PNG each (`ImageAsset`).
enum OrielBundle {
    static let fileExtension = "oriel"
    static let documentFileName = "document.json"
    /// Bumped when a change to the JSON would not be understood by older readers. Version 2 added image layers,
    /// patches and bars, step styles, the tone-down and the background's fills, shadow, inset, aspect and frame;
    /// every version 2 field has a default, so version 1 documents read as they always did.
    static let formatVersion = 2

    /// The app should declare this type (UTExportedTypeDeclarations, conforming to `com.apple.package`) so Finder
    /// shows bundles as single files; until then the type is derived from the extension.
    static var contentType: UTType {
        UTType(filenameExtension: fileExtension, conformingTo: .package) ?? .package
    }

    static func isBundle(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == fileExtension
    }

    /// Writes atomically: an existing bundle at `url` is replaced only once the new one is complete.
    static func write(_ document: EditorDocument, to url: URL) throws {
        guard let png = ImageFile.data(for: document.base.image, format: .png, scale: document.base.scale) else {
            throw OrielError.failed("The original image could not be encoded.")
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let json = try encoder.encode(Manifest(version: formatVersion, document: document))
        var files = [
            documentFileName: FileWrapper(regularFileWithContents: json),
            ImageRef.defaultFileName: FileWrapper(regularFileWithContents: png),
        ]
        let assets = document.assets
        if !assets.isEmpty {
            var images: [String: FileWrapper] = [:]
            for asset in assets {
                guard let data = ImageFile.data(for: asset.image, format: .png, scale: 1) else {
                    throw OrielError.failed("An image in the document could not be encoded.")
                }
                images[(asset.fileName as NSString).lastPathComponent] = FileWrapper(regularFileWithContents: data)
            }
            files[ImageAsset.folderName] = FileWrapper(directoryWithFileWrappers: images)
        }
        try FileWrapper(directoryWithFileWrappers: files).write(to: url, options: .atomic, originalContentsURL: nil)
    }

    static func read(from url: URL) throws -> EditorDocument {
        let bundle = try FileWrapper(url: url, options: .immediate)
        guard bundle.isDirectory, let files = bundle.fileWrappers,
              let json = files[documentFileName]?.regularFileContents,
              let png = files[ImageRef.defaultFileName]?.regularFileContents
        else {
            throw OrielError.invalidArgument("“\(url.lastPathComponent)” is not an Oriel document.")
        }
        guard let image = decode(png) else {
            throw OrielError.invalidArgument("The image in “\(url.lastPathComponent)” is damaged.")
        }
        let decoder = JSONDecoder()
        let version = try decoder.decode(VersionHeader.self, from: json).version
        guard version <= formatVersion else {
            throw OrielError.invalidArgument("“\(url.lastPathComponent)” was saved by a newer version of Oriel.")
        }
        var images = [ImageRef.defaultFileName: image]
        for (name, wrapper) in files[ImageAsset.folderName]?.fileWrappers ?? [:] {
            if let data = wrapper.regularFileContents, let asset = decode(data) {
                images["\(ImageAsset.folderName)/\(name)"] = asset
            }
        }
        if let key = ImageRef.imagesKey {
            decoder.userInfo[key] = images
        }
        return try decoder.decode(Manifest.self, from: json).document
    }

    private static func decode(_ data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
    }

    private struct Manifest: Codable {
        var version: Int
        var document: EditorDocument
    }

    private struct VersionHeader: Decodable {
        var version: Int
    }
}
