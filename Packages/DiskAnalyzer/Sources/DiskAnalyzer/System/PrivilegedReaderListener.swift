import Foundation
import Synchronization

/// The privileged helper's listener: accepts connections from Oriel only, checked by code signature, run by an
/// administrator (`Administrators`), serves each with `PrivilegedReaderService`, and calls `onIdle` when the last one
/// closes, which ends the helper; launchd starts it again for the next request.
final nonisolated class PrivilegedReaderListener: NSObject, NSXPCListenerDelegate, Sendable {
    private let requirement: String?
    private let admits: @Sendable (uid_t) -> Bool
    private let read: @Sendable (ElevatedRead.Request, CancellationFlag) -> ElevatedRead.Result
    private let onIdle: @Sendable () -> Void
    private let open = Mutex(0)

    /// A nil `requirement` accepts any client: only tests do that, on an anonymous listener. `admits` says whose
    /// processes, by effective user ID, may ask; `read` lists the folders (`PrivilegedReaderService`).
    init(
        requirement: String?,
        admits: @escaping @Sendable (uid_t) -> Bool = Administrators.contains,
        read: @escaping @Sendable (ElevatedRead.Request, CancellationFlag) -> ElevatedRead.Result = ElevatedRead.read(_:cancellation:),
        onIdle: @escaping @Sendable () -> Void
    ) {
        self.requirement = requirement
        self.admits = admits
        self.read = read
        self.onIdle = onIdle
    }

    func listener(_: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // A daemon is the whole Mac's: allowed once, it answers every account's Oriel. Only an administrator, who could
        // read these folders anyway with sudo, is answered; another user of the Mac would read other people's folders.
        guard admits(connection.effectiveUserIdentifier) else { return false }
        if let requirement {
            // A client that does not meet it is cut off before its first message is handled.
            connection.setCodeSigningRequirement(requirement)
        }
        connection.exportedInterface = NSXPCInterface(with: PrivilegedReading.self)
        let cancellation = CancellationFlag()
        connection.exportedObject = PrivilegedReaderService(cancellation: cancellation, read: read)
        open.withLock { $0 += 1 }
        connection.invalidationHandler = { [weak self] in
            // Oriel stopped waiting, or quit: the read in progress, if any, stops.
            cancellation.cancel()
            self?.closed()
        }
        connection.resume()
        return true
    }

    private func closed() {
        let remaining = open.withLock { count in
            count -= 1
            return count
        }
        if remaining == 0 {
            onIdle()
        }
    }
}
