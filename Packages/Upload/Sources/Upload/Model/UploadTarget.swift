import Foundation

/// Where a destination sends files, with the settings of that kind of service.
public nonisolated enum UploadTarget: Sendable, Equatable {
    case s3(UploadConfiguration)
    case webDAV(WebDAVConfiguration)
    case sftp(SFTPConfiguration)
    case sharedFolder(SharedFolderConfiguration)
    case dropbox(DropboxConfiguration)
    case googleDrive(GoogleDriveConfiguration)

    public var kind: UploadDestinationKind {
        switch self {
        case .s3: .s3
        case .webDAV: .webDAV
        case .sftp: .sftp
        case .sharedFolder: .sharedFolder
        case .dropbox: .dropbox
        case .googleDrive: .googleDrive
        }
    }

    /// A new destination's settings.
    public static func empty(_ kind: UploadDestinationKind) -> UploadTarget {
        switch kind {
        case .s3: .s3(UploadConfiguration())
        case .webDAV: .webDAV(WebDAVConfiguration())
        case .sftp: .sftp(SFTPConfiguration())
        case .sharedFolder: .sharedFolder(SharedFolderConfiguration())
        case .dropbox: .dropbox(DropboxConfiguration())
        case .googleDrive: .googleDrive(GoogleDriveConfiguration())
        }
    }

    /// What must still be filled in before an upload, in words ("a server address"), or nil. Secrets are checked
    /// separately, since they are in the Keychain.
    public var missingField: String? {
        switch self {
        case let .s3(configuration):
            if URL(string: configuration.endpoint)?.host == nil {
                return "an endpoint"
            }
            if configuration.bucket.isEmpty {
                return "a bucket"
            }
            return configuration.accessKey.isEmpty ? "an access key" : nil
        case let .webDAV(configuration): return configuration.missingField
        case let .sftp(configuration): return configuration.missingField
        case let .sharedFolder(configuration): return configuration.missingField
        case let .dropbox(configuration): return configuration.missingField
        case let .googleDrive(configuration): return configuration.missingField
        }
    }

    /// Why the settings cannot work as typed, or nil.
    public var problem: String? {
        switch self {
        case let .sftp(configuration): configuration.problem
        case let .dropbox(configuration): configuration.problem
        case let .googleDrive(configuration): configuration.problem
        case .s3, .webDAV, .sharedFolder: nil
        }
    }

    /// These settings with what an upload learned (`UploadReceipt.updatedTarget`): the Drive folder Oriel made, or the
    /// shared folder's new place. Only those fields change, so an edit the user made during the upload stays; a
    /// bookmark the user replaced meanwhile is not overwritten.
    public func learning(_ learned: UploadTarget, startedWith original: UploadTarget) -> UploadTarget {
        switch (self, learned, original) {
        case (var .googleDrive(current), let .googleDrive(found), _):
            current.createdFolderID = found.createdFolderID ?? current.createdFolderID
            return .googleDrive(current)
        case (var .sharedFolder(current), let .sharedFolder(found), let .sharedFolder(before)) where current.bookmark == before.bookmark:
            current.path = found.path
            current.bookmark = found.bookmark
            return .sharedFolder(current)
        default:
            return self
        }
    }

    /// The app key or client ID a signed-in service's tokens must come from.
    public var oauthClientID: String? {
        switch self {
        case let .dropbox(configuration): configuration.trimmedAppKey
        case let .googleDrive(configuration): configuration.trimmedClientID
        case .s3, .webDAV, .sftp, .sharedFolder: nil
        }
    }

    /// The template for the link to copy, for the kinds that have one.
    public var publicURLTemplate: String? {
        switch self {
        case let .webDAV(configuration): configuration.publicURLTemplate
        case let .sftp(configuration): configuration.publicURLTemplate
        case let .sharedFolder(configuration): configuration.publicURLTemplate
        case .s3, .dropbox, .googleDrive: nil
        }
    }
}
