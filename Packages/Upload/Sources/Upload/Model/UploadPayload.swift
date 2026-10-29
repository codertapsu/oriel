import Foundation

/// The file one upload sends: always a file on disk, so every destination can stream it instead of holding it in
/// memory (a recording can be gigabytes), and sftp can be handed a path.
public nonisolated struct UploadPayload: Sendable, Equatable {
    public let fileURL: URL
    /// What `{name}` becomes and the link's label: a window title, or the file's name without its extension.
    public let name: String
    public let fileExtension: String
    public let contentType: String
    public let byteCount: Int64
    public let isImage: Bool
    /// Whether the file is a temporary copy that goes once the upload is over.
    let ownsFile: Bool

    public init(fileURL: URL, name: String, fileExtension: String, contentType: String, byteCount: Int64, isImage: Bool, ownsFile: Bool) {
        self.fileURL = fileURL
        self.name = name
        self.fileExtension = fileExtension
        self.contentType = contentType
        self.byteCount = byteCount
        self.isImage = isImage
        self.ownsFile = ownsFile
    }
}
