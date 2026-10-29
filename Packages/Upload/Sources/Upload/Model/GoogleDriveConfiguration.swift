import Foundation

/// A Google Drive, through an OAuth client the user creates in the Google Cloud console. The client is of type iOS,
/// which Google also uses for macOS apps: it has no secret and redirects to its reversed client ID, a custom scheme
/// that `ASWebAuthenticationSession` catches. Sign-in is OAuth 2 with PKCE; the refresh token is in the Keychain.
public nonisolated struct GoogleDriveConfiguration: Codable, Sendable, Equatable {
    /// Which link to copy.
    public enum LinkStyle: String, Codable, CaseIterable, Sendable {
        /// The file's page in Drive (`webViewLink`).
        case page
        /// A direct download (`webContentLink`).
        case download

        public var title: String {
            switch self {
            case .page: "Drive page"
            case .download: "Direct download"
            }
        }
    }

    /// How much of Drive Oriel asks for.
    public enum Access: String, Codable, CaseIterable, Sendable {
        /// `drive.file`: only the files and folders Oriel creates. Google's recommended scope; no verification.
        case appFiles
        /// `drive`: all of Drive, needed to upload into a folder the user made. A restricted scope.
        case everything

        public var scope: String {
            switch self {
            case .appFiles: "https://www.googleapis.com/auth/drive.file"
            case .everything: "https://www.googleapis.com/auth/drive"
            }
        }

        public var title: String {
            switch self {
            case .appFiles: "Only files Oriel uploads"
            case .everything: "All of Google Drive"
            }
        }
    }

    /// The OAuth client ID, `<number>-<id>.apps.googleusercontent.com`.
    public var clientID: String
    /// The folder to upload into, by ID; a folder's link is accepted too. Empty: an "Oriel" folder Oriel makes.
    public var folderID: String
    /// The "Oriel" folder Oriel made, remembered so it is made once.
    public var createdFolderID: String?
    /// Give "anyone with the link" read access (`permissions.create`).
    public var sharesPublicly: Bool
    public var linkStyle: LinkStyle
    public var access: Access

    public init(
        clientID: String = "",
        folderID: String = "",
        createdFolderID: String? = nil,
        sharesPublicly: Bool = true,
        linkStyle: LinkStyle = .page,
        access: Access = .appFiles
    ) {
        self.clientID = clientID
        self.folderID = folderID
        self.createdFolderID = createdFolderID
        self.sharesPublicly = sharesPublicly
        self.linkStyle = linkStyle
        self.access = access
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            clientID: container.decodeIfPresent(String.self, forKey: .clientID) ?? "",
            folderID: container.decodeIfPresent(String.self, forKey: .folderID) ?? "",
            createdFolderID: container.decodeIfPresent(String.self, forKey: .createdFolderID),
            sharesPublicly: container.decodeIfPresent(Bool.self, forKey: .sharesPublicly) ?? true,
            linkStyle: container.decodeIfPresent(LinkStyle.self, forKey: .linkStyle) ?? .page,
            access: container.decodeIfPresent(Access.self, forKey: .access) ?? .appFiles
        )
    }

    static let clientIDSuffix = ".apps.googleusercontent.com"

    public var trimmedClientID: String {
        clientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The custom scheme of an iOS-type client: its ID reversed, `com.googleusercontent.apps.<number>-<id>`.
    public var callbackScheme: String {
        let id = trimmedClientID
        let prefix = id.hasSuffix(Self.clientIDSuffix) ? String(id.dropLast(Self.clientIDSuffix.count)) : id
        return "com.googleusercontent.apps.\(prefix)"
    }

    public var redirectURI: String {
        "\(callbackScheme):/oauth2redirect"
    }

    /// The folder ID, taken out of a pasted Drive link when needed; empty for "Oriel's own folder".
    public var resolvedFolderID: String {
        Self.folderID(from: folderID)
    }

    /// A folder ID from what the user pasted: the ID itself, `…/drive/folders/<id>?usp=sharing` or `…?id=<id>`.
    public static func folderID(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("/") || trimmed.contains("?"), let components = URLComponents(string: trimmed) else {
            return trimmed
        }
        if let id = components.queryItems?.first(where: { $0.name == "id" })?.value, !id.isEmpty {
            return id
        }
        let parts = components.path.split(separator: "/").map(String.init)
        if let index = parts.firstIndex(of: "folders"), parts.indices.contains(index + 1) {
            return parts[index + 1]
        }
        return parts.last ?? trimmed
    }

    /// What is still missing, in words, or nil.
    public var missingField: String? {
        trimmedClientID.isEmpty ? "a client ID" : nil
    }

    /// Why the client ID cannot be right, or nil.
    public var problem: String? {
        let id = trimmedClientID
        guard !id.isEmpty else { return nil }
        guard id.hasSuffix(Self.clientIDSuffix), !id.contains(where: \.isWhitespace) else {
            return "A client ID ends in .apps.googleusercontent.com."
        }
        return nil
    }

    /// A folder of the user's own needs all of Drive; Oriel's own folder needs only its files.
    public var foldersNeedFullAccess: Bool {
        !resolvedFolderID.isEmpty && access == .appFiles
    }
}
