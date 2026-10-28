@testable import OrielTranslation
import Synchronization

/// A `SecretStore` that never touches the real Keychain.
final class InMemorySecrets: SecretStore {
    private let values = Mutex<[String: String]>([:])

    func string(service: String, account: String) -> String? {
        values.withLock { $0["\(service)/\(account)"] }
    }

    func setString(_ value: String?, service: String, account: String) throws {
        values.withLock { $0["\(service)/\(account)"] = value?.isEmpty == false ? value : nil }
    }

    var services: [String] {
        values.withLock { $0.keys.map { String($0.split(separator: "/")[0]) }.sorted() }
    }
}
