import CryptoKit
import Foundation
import OrielCore

/// Seals Clipboard History's files with AES-GCM under one 256-bit key kept in the keychain, so copied passwords,
/// tokens and messages never sit on disk in the clear (CLAUDE.md rule 7).
nonisolated struct ClipboardVault: Sendable {
    static let keychainService = "clipboard"
    static let keychainAccount = "key"

    let key: SymmetricKey

    func seal(_ data: Data) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key).combined else {
            throw OrielError.failed("Clipboard History could not encrypt an item.")
        }
        return combined
    }

    func open(_ data: Data) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
    }

    /// The key from the keychain, made and saved the first time. A keychain that cannot be read (locked, or access
    /// refused) throws instead of getting a new key, which would leave the history unreadable for good.
    static func key(in keychain: KeychainStore) throws -> SymmetricKey {
        if let data = try keychain.data(service: keychainService, account: keychainAccount), data.count == 32 {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        try keychain.setData(key.withUnsafeBytes { Data($0) }, service: keychainService, account: keychainAccount)
        return key
    }
}
