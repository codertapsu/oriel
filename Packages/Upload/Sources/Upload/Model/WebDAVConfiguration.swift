import Foundation

/// A WebDAV server (Nextcloud, ownCloud, a NAS, Apache `mod_dav`): files are `PUT` below `serverURL/folder`, missing
/// folders made with `MKCOL`. The password is in the Keychain; the server chooses Basic or Digest.
public nonisolated struct WebDAVConfiguration: Codable, Sendable, Equatable {
    /// The WebDAV address, e.g. `https://cloud.example.com/remote.php/dav/files/marcus`.
    public var serverURL: String
    /// Empty for a server that needs no sign-in.
    public var username: String
    /// A folder below the server address, made when missing. Empty: the address itself.
    public var folder: String
    /// The link to copy, e.g. `https://files.example.com/{path}`. Empty: the file's WebDAV address.
    public var publicURLTemplate: String

    public init(serverURL: String = "", username: String = "", folder: String = "Oriel", publicURLTemplate: String = "") {
        self.serverURL = serverURL
        self.username = username
        self.folder = folder
        self.publicURLTemplate = publicURLTemplate
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            serverURL: container.decodeIfPresent(String.self, forKey: .serverURL) ?? "",
            username: container.decodeIfPresent(String.self, forKey: .username) ?? "",
            folder: container.decodeIfPresent(String.self, forKey: .folder) ?? "",
            publicURLTemplate: container.decodeIfPresent(String.self, forKey: .publicURLTemplate) ?? ""
        )
    }

    /// The server address, when it is an http or https URL with a host.
    public var server: URL? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              url.host?.isEmpty == false
        else {
            return nil
        }
        return url
    }

    /// The folder's path segments below the server address.
    public var folderSegments: [String] {
        UploadPath.segments(folder)
    }

    /// What is still missing, in words, or nil when uploads can start.
    public var missingField: String? {
        server == nil ? "a server address (https://…)" : nil
    }

    /// Basic authentication over plain HTTP sends the password readably; Settings warns about it.
    public var sendsPasswordInClear: Bool {
        server?.scheme?.lowercased() == "http" && !username.isEmpty
    }
}
