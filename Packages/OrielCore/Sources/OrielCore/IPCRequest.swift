import Foundation

/// One CLI command sent to the running app over the Unix socket, as one line of JSON (PLAN §7.1.8).
public struct IPCRequest: Codable, Sendable, Equatable {
    public var id: UUID
    /// Dotted verb, e.g. `windows.list`, `capture.area`, `debug.capabilities`.
    public var verb: String
    /// Positional arguments after the verb.
    public var arguments: [String]
    /// `--name value` options; flags without a value map to `"true"`.
    public var options: [String: String]

    public init(id: UUID = UUID(), verb: String, arguments: [String] = [], options: [String: String] = [:]) {
        self.id = id
        self.verb = verb
        self.arguments = arguments
        self.options = options
    }

    public func flag(_ name: String) -> Bool {
        options[name] == "true"
    }
}
