/// A CLI verb contributed by a module, routed to it by the app's IPC server.
public struct IPCCommandHandler: Sendable {
    public let verb: String
    /// One line for `oriel --help`, e.g. `windows list [--json] [--space current|all]`.
    public let usage: String
    public let handle: @MainActor @Sendable (IPCRequest) async -> IPCResponse

    public init(verb: String, usage: String, handle: @escaping @MainActor @Sendable (IPCRequest) async -> IPCResponse) {
        self.verb = verb
        self.usage = usage
        self.handle = handle
    }
}
