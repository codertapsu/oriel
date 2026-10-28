import Darwin
import Foundation
import OrielCore
import os

/// The app's end of the CLI channel (PLAN §7.1.8): a Unix domain socket with mode 0600 that only accepts peers
/// running as the same user, one JSON request per line in, one JSON response per line out.
///
/// Event-driven: a dispatch read source fires when a client connects, nothing polls.
public final class IPCServer: @unchecked Sendable {
    public typealias Handler = @Sendable (IPCRequest) async -> IPCResponse

    private let socketURL: URL
    private let handler: Handler
    private let queue = DispatchQueue(label: "com.codertapsu.oriel.ipc")
    private let log = Log.logger("ipc")
    // Only touched on `queue`.
    private var listener: Int32 = -1
    private var acceptSource: DispatchSourceRead?

    public init(socketURL: URL = AppPaths.ipcSocket, handler: @escaping Handler) {
        self.socketURL = socketURL
        self.handler = handler
    }

    deinit {
        acceptSource?.cancel()
    }

    public func start() throws {
        try queue.sync { try listen() }
    }

    public func stop() {
        queue.sync {
            acceptSource?.cancel()
            acceptSource = nil
            listener = -1
            unlink(socketURL.path)
        }
    }

    private func listen() throws {
        guard acceptSource == nil else { return }
        try FileManager.default.createDirectory(at: socketURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        // A socket left by a crashed run would make bind fail.
        unlink(socketURL.path)
        var address = try UnixSocket.address(for: socketURL)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw IPCError.system("socket", errno) }
        let bound = UnixSocket.withSockaddr(&address) { bind(fd, $0, $1) }
        guard bound == 0 else {
            let code = errno
            close(fd)
            throw IPCError.system("bind", code)
        }
        chmod(socketURL.path, 0o600)
        guard Darwin.listen(fd, 16) == 0 else {
            let code = errno
            close(fd)
            throw IPCError.system("listen", code)
        }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptPending() }
        source.setCancelHandler { close(fd) }
        source.resume()
        listener = fd
        acceptSource = source
    }

    private func acceptPending() {
        while true {
            let client = accept(listener, nil, nil)
            guard client >= 0 else { return } // EAGAIN: nothing left to accept
            var uid: uid_t = 0
            var gid: gid_t = 0
            guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else {
                log.error("refused an IPC connection from uid \(uid)")
                close(client)
                continue
            }
            // Blocking from here; a stuck client times out instead of pinning the queue.
            _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
            var timeout = timeval(tv_sec: 10, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            serve(client)
        }
    }

    private func serve(_ client: Int32) {
        let request: IPCRequest
        do {
            guard let line = try UnixSocket.readLine(from: client) else {
                close(client)
                return
            }
            request = try JSONDecoder().decode(IPCRequest.self, from: line)
        } catch {
            log.error("bad IPC request: \(error.localizedDescription, privacy: .public)")
            close(client)
            return
        }
        let handler = handler
        let log = log
        Task.detached {
            let response = await handler(request)
            do {
                var data = try JSONEncoder().encode(response)
                data.append(UInt8(ascii: "\n"))
                try UnixSocket.writeAll(data, to: client)
            } catch {
                log.error("could not answer \(request.verb, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
            close(client)
        }
    }
}
