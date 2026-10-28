import Foundation

/// The app's answer to an `IPCRequest`. The CLI prints `output` to stdout, `error` to stderr and exits with
/// `status`.
public struct IPCResponse: Codable, Sendable, Equatable {
    public var id: UUID
    public var status: Int32
    public var output: String
    public var error: String?

    public init(id: UUID, status: Int32 = 0, output: String = "", error: String? = nil) {
        self.id = id
        self.status = status
        self.output = output
        self.error = error
    }

    public static func ok(_ request: IPCRequest, _ output: String = "") -> IPCResponse {
        IPCResponse(id: request.id, output: output)
    }

    /// Exit status 1 for failures, 64 (EX_USAGE) for bad arguments.
    public static func failure(_ request: IPCRequest, _ message: String, status: Int32 = 1) -> IPCResponse {
        IPCResponse(id: request.id, status: status, error: message)
    }
}
