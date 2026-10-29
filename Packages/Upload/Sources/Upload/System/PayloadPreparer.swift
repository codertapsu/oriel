import CoreGraphics
import Foundation
import ImageIO
import SharedUI
import UniformTypeIdentifiers

/// Turns what is uploaded into a file on disk (`UploadPayload`), off the main thread: a capture is encoded as PNG,
/// and an image file the user uploads loses its metadata first when the destination says so. Each upload gets a
/// folder of its own in the temporary folder, which `cleanUp` removes.
nonisolated enum PayloadPreparer {
    static let folderName = "Oriel Uploads"

    /// A capture as a PNG, with its display scale as DPI (`ImageFile`). Encoding afresh leaves no camera or location
    /// metadata in it.
    static func image(_ image: CGImage, scale: CGFloat, name: String) throws -> UploadPayload {
        guard let data = ImageFile.data(for: image, format: .png, scale: scale) else {
            throw UploadError.failed("The image could not be encoded.")
        }
        let file = try temporaryFolder().appending(path: "upload.png")
        try data.write(to: file)
        return UploadPayload(
            fileURL: file, name: name, fileExtension: "png", contentType: UTType.png.preferredMIMEType ?? "image/png",
            byteCount: Int64(data.count), isImage: true, ownsFile: true
        )
    }

    /// Any file: sent as it is, or, for a still image when `stripsMetadata`, as a copy without its metadata.
    static func file(at url: URL, stripsMetadata: Bool) throws -> UploadPayload {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw UploadError.notFound("“\(url.lastPathComponent)” is not a file Oriel can upload.") }
        let type = UTType(filenameExtension: url.pathExtension)
        let isImage = type?.conforms(to: .image) == true
        let name = url.deletingPathExtension().lastPathComponent
        let contentType = type?.preferredMIMEType ?? "application/octet-stream"
        if stripsMetadata, let type, strippable.contains(where: type.conforms(to:)) {
            let copy = try temporaryFolder().appending(path: "upload.\(url.pathExtension)")
            try strippingMetadata(from: url, to: copy, type: type)
            let size = try copy.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return UploadPayload(
                fileURL: copy, name: name, fileExtension: url.pathExtension, contentType: contentType,
                byteCount: Int64(size), isImage: true, ownsFile: true
            )
        }
        return UploadPayload(
            fileURL: url, name: name, fileExtension: url.pathExtension, contentType: contentType,
            byteCount: Int64(values.fileSize ?? 0), isImage: isImage, ownsFile: false
        )
    }

    /// Removes the temporary copy, if the payload is one.
    static func cleanUp(_ payload: UploadPayload) {
        guard payload.ownsFile else { return }
        try? FileManager.default.removeItem(at: payload.fileURL.deletingLastPathComponent())
    }

    /// A new, empty folder for one upload's files.
    static func temporaryFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: folderName, directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Still images ImageIO can write. Animated GIFs, PDFs and WebP (which ImageIO only reads) go as they are.
    private static let strippable: [UTType] = [.jpeg, .png, .heic, .heif, .tiff]

    /// Copies the image data unchanged with no metadata but its orientation, so a photo still stands the right way
    /// up. When ImageIO cannot copy the format losslessly, the image is re-encoded instead.
    static func strippingMetadata(from source: URL, to destination: URL, type: UTType) throws {
        guard let input = CGImageSourceCreateWithURL(source as CFURL, nil), CGImageSourceGetCount(input) > 0 else {
            throw UploadError.failed("“\(source.lastPathComponent)” is not an image Oriel can read.")
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any] ?? [:]
        let orientation = properties[kCGImagePropertyOrientation] as? NSNumber ?? 1
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, 1, nil) else {
            throw UploadError.failed("Oriel can't write a copy of “\(source.lastPathComponent)”.")
        }
        let copyOptions: [CFString: Any] = [
            kCGImageDestinationMetadata: CGImageMetadataCreateMutable(),
            kCGImageDestinationMergeMetadata: false,
            kCGImageMetadataShouldExcludeXMP: true,
            kCGImageMetadataShouldExcludeGPS: true,
            kCGImageDestinationOrientation: orientation,
        ]
        if CGImageDestinationCopyImageSource(output, input, copyOptions as CFDictionary, nil) {
            return
        }
        try? FileManager.default.removeItem(at: destination)
        guard let image = CGImageSourceCreateImageAtIndex(input, 0, nil),
              let encoder = CGImageDestinationCreateWithURL(destination as CFURL, type.identifier as CFString, 1, nil)
        else {
            throw UploadError.failed("“\(source.lastPathComponent)” could not be copied without its metadata.")
        }
        let encodeOptions: [CFString: Any] = [kCGImagePropertyOrientation: orientation, kCGImageDestinationLossyCompressionQuality: 0.95]
        CGImageDestinationAddImage(encoder, image, encodeOptions as CFDictionary)
        guard CGImageDestinationFinalize(encoder) else {
            throw UploadError.failed("“\(source.lastPathComponent)” could not be copied without its metadata.")
        }
    }
}
