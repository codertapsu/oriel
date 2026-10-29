import OrielCore

/// The upload settings keys, all named `upload.*` (Settings → Upload). Secrets are in the Keychain, service
/// `upload.s3`, which Uninstall removes: each destination's under its own account (`UploadSecret`).
public nonisolated enum UploadSettings {
    /// The destinations and the default one.
    public static let destinations = SettingKey("upload.destinations", default: UploadDestinationList())
    /// Copy the link (in the destination's link format) once an upload is done.
    public static let copiesLink = SettingKey("upload.copiesLink", default: true)
    /// Oriel 0.1's single S3 destination. A bootstrap import still writes it; the destination list takes it in and
    /// clears it (`UploadDestinationStore`), so it is empty once Oriel has run.
    public static let configuration = SettingKey("upload.configuration", default: UploadConfiguration())
    public static let keychainService = "upload.s3"
    /// The account of Oriel 0.1's S3 secret key, which a bootstrap import still writes, and which moves to its
    /// destination's own account.
    public static let keychainAccount = "secretKey"
}
