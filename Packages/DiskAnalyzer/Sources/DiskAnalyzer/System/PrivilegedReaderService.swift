import Foundation

/// What the privileged helper does for Oriel, as root: lists folders by the scan's rules (`ElevatedRead.read`) and replies
/// with the listings. It reads directories and replies, nothing else.
final nonisolated class PrivilegedReaderService: NSObject, PrivilegedReading, Sendable {
    /// Set when the connection closes, as when Oriel stops waiting: the read stops, since nobody would get its answer.
    private let cancellation: CancellationFlag
    private let read: @Sendable (ElevatedRead.Request, CancellationFlag) -> ElevatedRead.Result

    /// `read` lists the folders: `ElevatedRead.read`, or a test's.
    init(
        cancellation: CancellationFlag = CancellationFlag(),
        read: @escaping @Sendable (ElevatedRead.Request, CancellationFlag) -> ElevatedRead.Result = ElevatedRead.read(_:cancellation:)
    ) {
        self.cancellation = cancellation
        self.read = read
    }

    /// Reads on a thread of its own: a connection handles one message at a time, so a read on the connection's queue
    /// would keep it from learning that Oriel hung up, and run to its end with nobody to answer.
    func readFolders(_ arguments: [String], reply: @escaping @Sendable (Data?, String?) -> Void) {
        guard let request = ElevatedRead.Request(arguments: arguments) else {
            reply(nil, "Oriel's helper did not understand the request.")
            return
        }
        let limited = ElevatedRead.Request(folders: Array(request.folders.prefix(ElevatedRead.folderLimit)), options: request.options)
        let cancellation = cancellation
        let read = read
        let thread = Thread {
            let result = read(limited, cancellation)
            guard !cancellation.isCancelled else { return }
            guard let data = try? JSONEncoder().encode(result) else {
                reply(nil, "Oriel's helper could not write what it read.")
                return
            }
            reply(data, nil)
        }
        thread.name = "Oriel disk reader"
        thread.qualityOfService = .userInitiated
        thread.start()
    }
}
