import Foundation
@testable import Upload

/// A fresh folder for one test, removed by `remove()`.
struct TemporaryFolder {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory.appending(path: "oriel-upload-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func remove() {
        // A test may have made a folder read-only.
        if let paths = FileManager.default.subpaths(atPath: url.path) {
            for path in paths {
                try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.appending(path: path).path)
            }
        }
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        try? FileManager.default.removeItem(at: url)
    }

    /// Writes `contents` to `name` inside the folder.
    @discardableResult
    func file(_ name: String, contents: Data) throws -> URL {
        let file = url.appending(path: name)
        try contents.write(to: file)
        return file
    }

    /// A payload for `contents`, written here.
    func payload(
        _ contents: Data,
        name: String = "Safari",
        fileExtension: String = "png",
        contentType: String = "image/png"
    ) throws -> UploadPayload {
        let file = try file("\(UUID().uuidString).\(fileExtension)", contents: contents)
        return UploadPayload(
            fileURL: file, name: name, fileExtension: fileExtension, contentType: contentType, byteCount: Int64(contents.count),
            isImage: contentType.hasPrefix("image/"), ownsFile: false
        )
    }
}
