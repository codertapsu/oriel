import Foundation

/// A folder on this Mac or a mounted volume (an SMB share, a NAS, a synced folder such as iCloud Drive or Dropbox):
/// uploads are copies into it. Oriel is not sandboxed, so the bookmark is a plain one; it is kept because it finds
/// the folder again after it is renamed or moved, where the path alone would not.
public nonisolated struct SharedFolderConfiguration: Codable, Sendable, Equatable {
    /// The folder's path when it was chosen, shown in Settings and used when the bookmark cannot be resolved.
    public var path: String
    public var bookmark: Data?
    /// The link to copy, e.g. `https://files.example.com/{path}` for a web server that serves the folder. Empty: the
    /// file's `smb://` address on a network share, else its `file://` URL.
    public var publicURLTemplate: String

    public init(path: String = "", bookmark: Data? = nil, publicURLTemplate: String = "") {
        self.path = path
        self.bookmark = bookmark
        self.publicURLTemplate = publicURLTemplate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            path: container.decodeIfPresent(String.self, forKey: .path) ?? "",
            bookmark: container.decodeIfPresent(Data.self, forKey: .bookmark),
            publicURLTemplate: container.decodeIfPresent(String.self, forKey: .publicURLTemplate) ?? ""
        )
    }

    /// What is still missing, in words, or nil when uploads can start.
    public var missingField: String? {
        path.isEmpty && bookmark == nil ? "a folder" : nil
    }
}
