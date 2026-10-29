import Foundation
import Security

/// Secrets (provider API keys, upload credentials) in the login keychain, never in UserDefaults or logs
/// (PLAN §7.7.5, §8.4).
///
/// Each item is a generic password whose service is `<prefix>.<service>`, readable only on this Mac after
/// the first unlock.
public struct KeychainStore: Sendable {
    public let prefix: String

    public init(prefix: String = "com.codertapsu.oriel") {
        self.prefix = prefix
    }

    public func string(service: String, account: String = "default") -> String? {
        (try? data(service: service, account: account)).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// The item's bytes; nil only when there is no such item. A locked keychain, or access refused, throws, so a
    /// caller never mistakes it for a missing item and replaces a key it could not read.
    public func data(service: String, account: String = "default") throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = result as? Data else { throw OrielError.keychain(status) }
        return data
    }

    /// Stores `value`, or deletes the item when `value` is nil or empty.
    public func setString(_ value: String?, service: String, account: String = "default") throws {
        try setData(value.map { Data($0.utf8) }, service: service, account: account)
    }

    /// Stores `value`, or deletes the item when `value` is nil or empty.
    public func setData(_ value: Data?, service: String, account: String = "default") throws {
        let query = baseQuery(service: service, account: account)
        guard let value, !value.isEmpty else {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw OrielError.keychain(status) }
            return
        }
        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw OrielError.keychain(status) }
    }

    /// Deletes every account of `service`.
    public func remove(service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(prefix).\(service)",
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw OrielError.keychain(status) }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(prefix).\(service)",
            kSecAttrAccount as String: account,
        ]
    }
}
