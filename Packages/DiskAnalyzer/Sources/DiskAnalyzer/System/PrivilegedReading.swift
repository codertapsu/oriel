import Foundation

/// The privileged helper's XPC interface (`PrivilegedReader`, `PrivilegedReaderService`).
@objc(OrielPrivilegedReading)
nonisolated protocol PrivilegedReading {
    /// Lists the folders `arguments` names, in `ElevatedRead.Request`'s form, and replies with the JSON of an
    /// `ElevatedRead.Result`, or with no data and why.
    func readFolders(_ arguments: [String], reply: @escaping @Sendable (Data?, String?) -> Void)
}
