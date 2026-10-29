import CryptoKit
import Darwin

/// SHA-256 of files for the duplicate finder: of their first and last 64 KB, which tells most different files apart
/// after one read at each end, and of all of their content, streamed a megabyte at a time. Never follows a symbolic
/// link; returns nil for a file it cannot read, including one that is only in the cloud.
nonisolated enum FileHasher {
    static let edge = 64 * 1024
    static let chunk = 1024 * 1024

    static func edges(of path: String, size: Int64) -> String? {
        let descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        var hasher = SHA256()
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: edge, alignment: 16)
        defer { buffer.deallocate() }
        var offsets: [Int64] = [0]
        if size > Int64(edge) {
            offsets.append(max(Int64(edge), size - Int64(edge)))
        }
        for offset in offsets {
            let count = pread(descriptor, buffer.baseAddress, edge, off_t(offset))
            guard count >= 0 else { return nil }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(rebasing: buffer[..<count]))
        }
        return hex(hasher.finalize())
    }

    /// `onBytes` gets the bytes read since its last call, for progress.
    static func full(of path: String, cancellation: CancellationFlag, onBytes: (Int) -> Void) -> String? {
        let descriptor = open(path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        // The data is read once; keeping it out of the cache leaves room for what the user is doing.
        _ = fcntl(descriptor, F_NOCACHE, 1)
        var hasher = SHA256()
        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: chunk, alignment: 16)
        defer { buffer.deallocate() }
        while true {
            guard !cancellation.isCancelled else { return nil }
            let count = read(descriptor, buffer.baseAddress, chunk)
            if count == 0 {
                break
            }
            guard count > 0 else { return nil }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(rebasing: buffer[..<count]))
            onBytes(count)
        }
        return hex(hasher.finalize())
    }

    private static func hex(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}
