import Darwin
import Foundation

/// The few POSIX socket calls both ends need.
enum UnixSocket {
    static func address(for url: URL) throws -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let path = Array(url.path.utf8CString)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.count <= capacity else { throw IPCError.pathTooLong }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            path.withUnsafeBytes { buffer.copyMemory(from: $0) }
        }
        return address
    }

    static func withSockaddr<T>(_ address: inout sockaddr_un, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T) -> T {
        withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { body($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
    }

    /// Writes all of `data`, retrying short writes.
    static func writeAll(_ data: Data, to fd: Int32) throws {
        try data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(fd, base + offset, buffer.count - offset)
                if written < 0 {
                    if errno == EINTR {
                        continue
                    }
                    throw IPCError.system("write", errno)
                }
                offset += written
            }
        }
    }

    /// Reads up to the first newline (excluded), or to EOF. `nil` on EOF before any byte.
    static func readLine(from fd: Int32, limit: Int = 16 << 20) throws -> Data? {
        var line = Data()
        var byte: UInt8 = 0
        while line.count < limit {
            let count = Darwin.read(fd, &byte, 1)
            if count == 0 {
                return line.isEmpty ? nil : line
            }
            if count < 0 {
                if errno == EINTR {
                    continue
                }
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    throw IPCError.timeout
                }
                throw IPCError.system("read", errno)
            }
            if byte == UInt8(ascii: "\n") {
                return line
            }
            line.append(byte)
        }
        throw IPCError.malformedMessage
    }
}
