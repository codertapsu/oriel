import Darwin
import Foundation

/// `ProcessRunning` with `Foundation.Process`. Standard output and error are read to their end on background queues,
/// so a tool that prints a lot never stalls on a full pipe; standard input is written once and closed. The tool
/// inherits Oriel's environment, which carries `SSH_AUTH_SOCK`, so ssh finds the user's agent.
nonisolated struct SystemProcessRunner: ProcessRunning {
    func run(_ executable: URL, arguments: [String], input: Data) async throws -> ProcessResult {
        try Task.checkCancellation()
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let standardInput = Pipe()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError
        // A tool that exits before reading its input must not take Oriel down with SIGPIPE.
        _ = fcntl(standardInput.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)

        async let output = Self.readToEnd(standardOutput.fileHandleForReading)
        async let errors = Self.readToEnd(standardError.fileHandleForReading)
        let status: Int32
        do {
            status = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    process.terminationHandler = { process in
                        continuation.resume(returning: process.terminationStatus)
                    }
                    do {
                        try process.run()
                    } catch {
                        process.terminationHandler = nil
                        continuation.resume(throwing: error)
                        return
                    }
                    let writer = standardInput.fileHandleForWriting
                    DispatchQueue.global(qos: .utility).async {
                        try? writer.write(contentsOf: input)
                        try? writer.close()
                    }
                }
            } onCancel: {
                if process.isRunning {
                    process.terminate()
                }
            }
        } catch {
            // The tool never started: close the pipes' other ends, so the readers see their end.
            try? standardOutput.fileHandleForWriting.close()
            try? standardError.fileHandleForWriting.close()
            _ = await (output, errors)
            throw UploadError.failed("\(executable.lastPathComponent) could not start: \(error.localizedDescription)")
        }
        let result = await ProcessResult(status: status, standardOutput: output, standardError: errors)
        if Task.isCancelled {
            throw UploadError.cancelled
        }
        return result
    }

    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: (try? handle.readToEnd()) ?? Data())
            }
        }
    }
}
