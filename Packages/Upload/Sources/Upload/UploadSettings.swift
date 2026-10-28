import OrielCore

/// The upload settings keys. The secret key is in the Keychain, service `upload.s3`.
public enum UploadSettings {
    public static let configuration = SettingKey("upload.configuration", default: UploadConfiguration())
    public static let copiesLink = SettingKey("upload.copiesLink", default: true)
    public static let keychainService = "upload.s3"
    public static let keychainAccount = "secretKey"
}
