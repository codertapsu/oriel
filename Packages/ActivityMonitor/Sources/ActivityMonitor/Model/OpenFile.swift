/// One of a process's open files or sockets, from `PROC_PIDLISTFDS` and `proc_pidfdinfo`, which macOS answers for the
/// user's own processes.
nonisolated struct OpenFile: Sendable, Equatable, Hashable {
    enum Kind: String, Sendable {
        case file
        case directory
        case tcp
        case udp
        case unixSocket
        case pipe
        case other
    }

    let descriptor: Int32
    let kind: Kind
    /// A path, `10.0.0.2:52167 → 17.57.145.54:443`, or the descriptor's type.
    let detail: String
    /// A TCP connection's state ("Established").
    let state: String?

    var symbol: String {
        switch kind {
        case .file: "doc"
        case .directory: "folder"
        case .tcp, .udp: "network"
        case .unixSocket: "point.3.connected.trianglepath.dotted"
        case .pipe: "arrow.left.arrow.right"
        case .other: "questionmark.square.dashed"
        }
    }

    /// TCP states as `netstat` names them, from `tcpsi_state`.
    static func tcpState(_ value: Int32) -> String? {
        let names = [
            "Closed", "Listening", "SYN sent", "SYN received", "Established", "Close wait", "FIN wait 1", "Closing", "Last ACK",
            "FIN wait 2", "Time wait",
        ]
        return names.indices.contains(Int(value)) ? names[Int(value)] : nil
    }
}
