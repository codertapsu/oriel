import Foundation

/// One place uploads can go (Settings → Upload): a service with its settings, plus what every destination has, the
/// name template for the uploaded file and the form of the copied link. Secrets are in the Keychain, under the
/// destination's ID (`UploadSecret`).
public nonisolated struct UploadDestination: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// The user's name for it ("Team NAS").
    public var name: String
    public var target: UploadTarget
    /// The uploaded file's path below the destination's folder (`UploadNameTemplate`), without the extension.
    public var nameTemplate: String
    /// How the link is copied: the link alone, Markdown or HTML.
    public var linkFormat: UploadLinkFormat
    /// Copy image files without their metadata (camera, location, editing history) before uploading them. Captures
    /// are encoded afresh and carry none anyway.
    public var stripsMetadata: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        target: UploadTarget,
        nameTemplate: String? = nil,
        linkFormat: UploadLinkFormat = .url,
        stripsMetadata: Bool = true
    ) {
        self.id = id
        self.name = name
        self.target = target
        self.nameTemplate = nameTemplate ?? target.kind.defaultNameTemplate
        self.linkFormat = linkFormat
        self.stripsMetadata = stripsMetadata
    }

    public var kind: UploadDestinationKind {
        target.kind
    }

    /// The name, or the kind's when the user cleared it.
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? kind.defaultName : trimmed
    }

    // MARK: Coding

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, nameTemplate, linkFormat, stripsMetadata
        case s3, webDAV = "webdav", sftp, sharedFolder = "folder", dropbox, googleDrive
    }

    /// A missing setting takes its default; an unknown kind throws, and the list leaves that destination out.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(UploadDestinationKind.self, forKey: .kind)
        let target: UploadTarget = switch kind {
        case .s3: try .s3(container.decodeIfPresent(UploadConfiguration.self, forKey: .s3) ?? UploadConfiguration())
        case .webDAV: try .webDAV(container.decodeIfPresent(WebDAVConfiguration.self, forKey: .webDAV) ?? WebDAVConfiguration())
        case .sftp: try .sftp(container.decodeIfPresent(SFTPConfiguration.self, forKey: .sftp) ?? SFTPConfiguration())
        case .sharedFolder:
            try .sharedFolder(container
                .decodeIfPresent(SharedFolderConfiguration.self, forKey: .sharedFolder) ?? SharedFolderConfiguration())
        case .dropbox: try .dropbox(container.decodeIfPresent(DropboxConfiguration.self, forKey: .dropbox) ?? DropboxConfiguration())
        case .googleDrive:
            try .googleDrive(container.decodeIfPresent(GoogleDriveConfiguration.self, forKey: .googleDrive) ?? GoogleDriveConfiguration())
        }
        try self.init(
            id: container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: container.decodeIfPresent(String.self, forKey: .name) ?? kind.defaultName,
            target: target,
            nameTemplate: container.decodeIfPresent(String.self, forKey: .nameTemplate),
            linkFormat: container.decodeIfPresent(UploadLinkFormat.self, forKey: .linkFormat) ?? .url,
            stripsMetadata: container.decodeIfPresent(Bool.self, forKey: .stripsMetadata) ?? true
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(nameTemplate, forKey: .nameTemplate)
        try container.encode(linkFormat, forKey: .linkFormat)
        try container.encode(stripsMetadata, forKey: .stripsMetadata)
        switch target {
        case let .s3(configuration): try container.encode(configuration, forKey: .s3)
        case let .webDAV(configuration): try container.encode(configuration, forKey: .webDAV)
        case let .sftp(configuration): try container.encode(configuration, forKey: .sftp)
        case let .sharedFolder(configuration): try container.encode(configuration, forKey: .sharedFolder)
        case let .dropbox(configuration): try container.encode(configuration, forKey: .dropbox)
        case let .googleDrive(configuration): try container.encode(configuration, forKey: .googleDrive)
        }
    }
}
