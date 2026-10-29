/// One run of a program: its pid and when it started. macOS reuses pids, so a pid alone could name another program by
/// the time the user acts on it; everything that is kept between samples, or checked before a signal, uses this.
nonisolated struct ProcessIdentity: Hashable, Sendable, Codable, CustomStringConvertible {
    let pid: Int32
    /// Microseconds since 1970, from the kernel's process table.
    let startTime: UInt64

    var description: String {
        "\(pid)@\(startTime)"
    }
}
