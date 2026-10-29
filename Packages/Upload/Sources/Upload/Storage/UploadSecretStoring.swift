import Foundation
import OrielCore

/// Where destinations' secrets live. In the app this is the Keychain (`KeychainStore`); tests use an in-memory store,
/// so they never touch the real Keychain or make it ask for anything.
public nonisolated protocol UploadSecretStoring: Sendable {
    /// The item's bytes; nil only when there is none. A locked keychain throws.
    func data(service: String, account: String) throws -> Data?
    /// Stores `value`, or deletes the item when `value` is nil or empty.
    func setData(_ value: Data?, service: String, account: String) throws
}

extension KeychainStore: UploadSecretStoring {}

public nonisolated extension UploadSecretStoring {
    func string(_ secret: UploadSecret, for destination: UUID) throws -> String? {
        try data(service: UploadSettings.keychainService, account: secret.account(for: destination))
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    func setString(_ value: String?, _ secret: UploadSecret, for destination: UUID) throws {
        try setData(value.map { Data($0.utf8) }, service: UploadSettings.keychainService, account: secret.account(for: destination))
    }

    func tokens(for destination: UUID) throws -> OAuthTokens? {
        guard let data = try data(service: UploadSettings.keychainService, account: UploadSecret.oauthTokens.account(for: destination))
        else {
            return nil
        }
        return try? JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    func setTokens(_ tokens: OAuthTokens?, for destination: UUID) throws {
        let data = try tokens.map { try JSONEncoder().encode($0) }
        try setData(data, service: UploadSettings.keychainService, account: UploadSecret.oauthTokens.account(for: destination))
    }

    /// Deletes every secret a destination may have.
    func removeSecrets(for destination: UUID) throws {
        for secret in UploadSecret.allCases {
            try setData(nil, service: UploadSettings.keychainService, account: secret.account(for: destination))
        }
    }
}
