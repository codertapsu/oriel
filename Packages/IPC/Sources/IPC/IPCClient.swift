import Darwin
import Foundation
import OrielCore

/// The CLI's end: connect, send one request, wait for its response.
public enum IPCClient {
    /// `timeout` covers the whole exchange; interactive commands (selecting an area) need a long one.
    public static func send(
        _ request: IPCRequest,
        to socketURL: URL = AppPaths.ipcSocket,
        timeout: TimeInterval = 30
    ) throws -> IPCResponse {
        var address = try UnixSocket.address(for: socketURL)
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw IPCError.system("socket", errno) }
        defer { close(fd) }
        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
        let connected = UnixSocket.withSockaddr(&address) { connect(fd, $0, $1) }
        guard connected == 0 else {
            if errno == ENOENT || errno == ECONNREFUSED {
                throw IPCError.appNotRunning
            }
            throw IPCError.system("connect", errno)
        }
        var limit = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - timeout.rounded(.down)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &limit, socklen_t(MemoryLayout<timeval>.size))
        var data = try JSONEncoder().encode(request)
        data.append(UInt8(ascii: "\n"))
        try UnixSocket.writeAll(data, to: fd)
        guard let line = try UnixSocket.readLine(from: fd), let response = try? JSONDecoder().decode(IPCResponse.self, from: line),
              response.id == request.id
        else {
            throw IPCError.malformedMessage
        }
        return response
    }
}
