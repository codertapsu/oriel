import Foundation
import OrielCore
import OrielTranslation
import os
import Upload

/// Imports `bootstrap.json` into settings and the Keychain, then deletes the file (PLAN §7.7.5). The file comes
/// from `make install`, a disk-image post-install step or MDM; a managed `BootstrapURL` preference can point at
/// an internal HTTPS copy instead.
@MainActor
struct BootstrapImporter {
    let settings: SettingsStore
    let keychain: KeychainStore
    /// The local file; tests point it elsewhere.
    var file = AppPaths.bootstrapFile
    /// Hands the translation half to the feature hub, which owns the providers.
    let applyProviders: ([BootstrapProvider], String?) -> Void

    private let log = Log.logger("bootstrap")

    /// The local file wins; otherwise the managed URL, if any. Returns what was imported, for the UI.
    @discardableResult
    func importAvailable() async -> String? {
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let summary = try apply(Data(contentsOf: file))
                // Secrets are now in the Keychain; the plain-text copy goes.
                try? FileManager.default.removeItem(at: file)
                return summary
            } catch {
                log.error("bootstrap.json was not imported: \(error.localizedDescription, privacy: .public)")
                return "bootstrap.json could not be read: \(error.localizedDescription)"
            }
        }
        guard let address = UserDefaults.standard.string(forKey: "BootstrapURL"), let url = URL(string: address),
              url.scheme == "https"
        else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try apply(data)
        } catch {
            log.error("BootstrapURL was not imported: \(error.localizedDescription, privacy: .public)")
            return "The shared configuration at \(url.host ?? "the configured URL") could not be loaded."
        }
    }

    func apply(_ data: Data) throws -> String {
        let config = try JSONDecoder().decode(BootstrapConfig.self, from: data)
        guard config.version == 1 else { throw OrielError.invalidArgument("Unsupported bootstrap version \(config.version).") }
        var parts: [String] = []
        if let providers = config.providers, !providers.isEmpty {
            applyProviders(providers, config.defaultProvider)
            parts.append("\(providers.count) translation provider\(providers.count == 1 ? "" : "s")")
        }
        if let upload = config.upload, upload.kind == "s3" {
            settings[UploadSettings.configuration] = UploadConfiguration(
                endpoint: upload.endpoint, region: upload.region ?? "us-east-1", bucket: upload.bucket,
                accessKey: upload.accessKey, pathPrefix: upload.pathPrefix ?? "",
                publicBaseURL: upload.publicBaseURL ?? "", usesPathStyle: upload.usesPathStyle ?? true
            )
            if let secret = upload.secretKey, !secret.isEmpty, !secret.hasPrefix("…") {
                try keychain.setString(secret, service: UploadSettings.keychainService, account: UploadSettings.keychainAccount)
            }
            parts.append("the upload destination")
        }
        settings[AppSettings.lastBootstrapImport] = Date()
        return parts.isEmpty ? "The shared configuration had nothing to import." : "Imported \(parts.joined(separator: " and "))."
    }
}
