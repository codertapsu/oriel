import CoreGraphics
import Foundation
import ImageIO
import OrielCore
import SharedUI
import UniformTypeIdentifiers

/// The editable `.oriel` document: a package directory with `document.json` (the document, annotations and all)
/// and `original.png` (the untouched base image, lossless).
enum OrielBundle {
    static let fileExtension = "oriel"
    static let documentFileName = "document.json"
    /// Bumped when a change to the JSON would not be understood by older readers.
    static let formatVersion = 1

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
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json = try encoder.encode(Manifest(version: formatVersion, document: document))
        let bundle = FileWrapper(directoryWithFileWrappers: [
            documentFileName: FileWrapper(regularFileWithContents: json),
            ImageRef.defaultFileName: FileWrapper(regularFileWithContents: png),
        ])
        try bundle.write(to: url, options: .atomic, originalContentsURL: nil)
    }

    static func read(from url: URL) throws -> EditorDocument {
        let bundle = try FileWrapper(url: url, options: .immediate)
        guard bundle.isDirectory, let files = bundle.fileWrappers,
              let json = files[documentFileName]?.regularFileContents,
              let png = files[ImageRef.defaultFileName]?.regularFileContents
        else {
            throw OrielError.invalidArgument("“\(url.lastPathComponent)” is not an Oriel document.")
        }
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
        else {
            throw OrielError.invalidArgument("The image in “\(url.lastPathComponent)” is damaged.")
        }
        let decoder = JSONDecoder()
        if let key = ImageRef.imagesKey {
            decoder.userInfo[key] = [ImageRef.defaultFileName: image]
        }
        let version = try decoder.decode(VersionHeader.self, from: json).version
        guard version <= formatVersion else {
            throw OrielError.invalidArgument("“\(url.lastPathComponent)” was saved by a newer version of Oriel.")
        }
        return try decoder.decode(Manifest.self, from: json).document
    }

    private struct Manifest: Codable {
        var version: Int
        var document: EditorDocument
    }

    private struct VersionHeader: Decodable {
        var version: Int
    }
}
