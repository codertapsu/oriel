import Foundation

public enum IPCError: LocalizedError, Sendable, Equatable {
    /// No socket, or nobody listening: Oriel is not running.
    case appNotRunning
    case timeout
    case malformedMessage
    case pathTooLong
    case system(String, Int32)

    public var errorDescription: String? {
        switch self {
        case .appNotRunning: "Oriel is not running. Start it, then try again."
        case .timeout: "Oriel did not answer in time."
        case .malformedMessage: "Oriel sent a reply this version of the CLI does not understand."
        case .pathTooLong: "The socket path is longer than a Unix socket allows."
        case let .system(call, code): "\(call) failed: \(String(cString: strerror(code)))"
        }
    }
}
