import Foundation
import Synchronization
@testable import Upload

/// An `UploadSecretStoring` that never touches the real Keychain. `locked` makes every call throw, like a locked
/// keychain.
final class InMemorySecrets: UploadSecretStoring {
    private let values = Mutex<[String: Data]>([:])
    private let isLocked = Mutex(false)

    struct Locked: Error {}

    var locked: Bool {
        get { isLocked.withLock { $0 } }
        set { isLocked.withLock { $0 = newValue } }
    }

    func data(service: String, account: String) throws -> Data? {
        if locked {
            throw Locked()
        }
        return values.withLock { $0["\(service)/\(account)"] }
    }

    func setData(_ value: Data?, service: String, account: String) throws {
        if locked {
            throw Locked()
        }
        values.withLock { $0["\(service)/\(account)"] = value?.isEmpty == false ? value : nil }
    }

    func string(service: String, account: String) -> String? {
        values.withLock { $0["\(service)/\(account)"] }.map(\.utf8Text)
    }

    /// The accounts stored, for checking what a migration or a removal left.
    var accounts: [String] {
        values.withLock { $0.keys.map { String($0.split(separator: "/", maxSplits: 1)[1]) }.sorted() }
    }
}
