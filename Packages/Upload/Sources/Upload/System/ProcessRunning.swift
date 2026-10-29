import Foundation

/// Runs a command-line tool to its end: the seam between the SFTP destination and `/usr/bin/sftp`, so tests hand in a
/// fake and never open an SSH connection.
public nonisolated protocol ProcessRunning: Sendable {
    /// Runs `executable` with `arguments`, writes `input` to its standard input and closes it, and returns once the
    /// tool has exited. Cancelling the task terminates the tool.
    func run(_ executable: URL, arguments: [String], input: Data) async throws -> ProcessResult
}
