import AppKit
import ImageIO
import OrielCore
import SharedUI
import UniformTypeIdentifiers

/// "Upload" from the Quick Access Overlay, the editor and pins: encode, upload, copy the link, tell the user.
@MainActor
public final class UploadCoordinator {
    private let settings: SettingsStore
    private let keychain: KeychainStore
    private let log = Log.logger("upload")

    public init(settings: SettingsStore, keychain: KeychainStore) {
        self.settings = settings
        self.keychain = keychain
    }

    public var isConfigured: Bool {
        settings[UploadSettings.configuration].isComplete && secretKey != nil
    }

    /// Uploads a PNG of `image` and returns its link; also copies it and shows a toast.
    @discardableResult
    public func upload(_ image: CGImage, scale: CGFloat = 2, name: String = "Oriel") async -> URL? {
        guard let data = ImageFile.data(for: image, format: .png, scale: scale) else { return nil }
        return await upload(data, fileName: "\(Self.safeName(name)).png", contentType: UTType.png.preferredMIMEType ?? "image/png")
    }

    /// Uploads any file (a recording, an export) and returns its link.
    @discardableResult
    public func upload(fileAt url: URL) async -> URL? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let type = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        return await upload(data, fileName: url.lastPathComponent, contentType: type)
    }

    /// Uploads and deletes a tiny object, for "Test connection".
    public func testConnection() async -> String {
        let configuration = settings[UploadSettings.configuration]
        let uploader = S3Uploader(configuration: configuration, secretKey: secretKey ?? "")
        let key = configuration.makeKey(fileName: "oriel-connection-test.txt")
        do {
            try await uploader.upload(Data("Oriel connection test".utf8), key: key, contentType: "text/plain")
            try? await uploader.delete(key: key)
            return "Connected: upload and delete both worked."
        } catch {
            return error.localizedDescription
        }
    }

    private func upload(_ data: Data, fileName: String, contentType: String) async -> URL? {
        let configuration = settings[UploadSettings.configuration]
        let uploader = S3Uploader(configuration: configuration, secretKey: secretKey ?? "")
        do {
            let link = try await uploader.upload(data, key: configuration.makeKey(fileName: fileName), contentType: contentType)
            if settings[UploadSettings.copiesLink] {
                Pasteboard.copy(link.absoluteString)
                Toast.show("Uploaded — link copied", symbol: "icloud.and.arrow.up")
            } else {
                Toast.show("Uploaded", symbol: "icloud.and.arrow.up")
            }
            return link
        } catch {
            log.error("upload failed: \(error.localizedDescription, privacy: .public)")
            Toast.show(error.localizedDescription, symbol: "exclamationmark.triangle")
            return nil
        }
    }

    private var secretKey: String? {
        keychain.string(service: UploadSettings.keychainService, account: UploadSettings.keychainAccount)
    }

    private static func safeName(_ name: String) -> String {
        let cleaned = name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "-")
        return cleaned.isEmpty ? "Oriel" : cleaned
    }
}
