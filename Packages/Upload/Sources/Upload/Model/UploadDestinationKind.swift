/// The services an upload destination can be (PLAN §7.8, §17). Raw values are stored in settings, so they never change.
public nonisolated enum UploadDestinationKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case s3
    case webDAV = "webdav"
    case sftp
    case sharedFolder = "folder"
    case dropbox
    case googleDrive

    public var id: String {
        rawValue
    }

    /// The name in Settings and in a new destination's name.
    public var title: String {
        switch self {
        case .s3: "S3-Compatible Storage"
        case .webDAV: "WebDAV"
        case .sftp: "SFTP"
        case .sharedFolder: "Shared Folder"
        case .dropbox: "Dropbox"
        case .googleDrive: "Google Drive"
        }
    }

    /// A short name for a new destination, numbered when it is taken ("WebDAV 2").
    public var defaultName: String {
        switch self {
        case .s3: "S3"
        default: title
        }
    }

    /// An SF Symbol; generic ones, since brand logos are not symbols.
    public var symbol: String {
        switch self {
        case .s3: "cylinder.split.1x2"
        case .webDAV: "network"
        case .sftp: "terminal"
        case .sharedFolder: "folder.badge.person.crop"
        case .dropbox: "shippingbox"
        case .googleDrive: "externaldrive.badge.icloud"
        }
    }

    /// What the Add Destination menu says about it.
    public var summary: String {
        switch self {
        case .s3: "AWS S3, MinIO, Cloudflare R2, Backblaze B2"
        case .webDAV: "Nextcloud, ownCloud, a NAS, any WebDAV server"
        case .sftp: "Any SSH server, with your SSH key"
        case .sharedFolder: "A mounted share, a synced folder or a NAS"
        case .dropbox: "Your Dropbox, through a Dropbox app you create"
        case .googleDrive: "Your Google Drive, through an OAuth client you create"
        }
    }

    /// The name template a new destination starts with. Where the link is the file's address (S3, WebDAV, SFTP, a
    /// shared folder), a random folder keeps links unguessable (PLAN §8.4); Dropbox and Google Drive links are
    /// unguessable anyway, so their files get readable names.
    public var defaultNameTemplate: String {
        switch self {
        case .s3, .webDAV, .sftp, .sharedFolder: UploadNameTemplate.unguessable
        case .dropbox, .googleDrive: UploadNameTemplate.readable
        }
    }

    /// Whether it signs in with OAuth in a browser sheet.
    public var usesOAuth: Bool {
        self == .dropbox || self == .googleDrive
    }
}
