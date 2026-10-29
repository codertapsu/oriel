import Foundation

/// Runs a system command-line tool and collects what it prints, on a thread of its own.
nonisolated enum ProcessRunner {
    struct Result: Sendable, Equatable {
        var status: Int32
        var output: String
        var error: String

        var succeeded: Bool {
            status == 0
        }
    }

    static func run(_ executable: String, _ arguments: [String]) async -> Result {
        await withCheckedContinuation { continuation in
            let thread = Thread {
                continuation.resume(returning: runBlocking(executable, arguments))
            }
            thread.name = "Oriel tool"
            thread.start()
        }
    }

    private static func runBlocking(_ executable: String, _ arguments: [String]) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return Result(status: -1, output: "", error: error.localizedDescription)
        }
        // Errors are read on another thread, so a full pipe on one side never blocks the other.
        let errorText = ErrorCollector(errors.fileHandleForReading)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(
            status: process.terminationStatus,
            output: String(data: data, encoding: .utf8) ?? "",
            error: errorText.wait()
        )
    }

    /// Reads a pipe to its end on its own thread.
    private final class ErrorCollector: @unchecked Sendable {
        private let done = DispatchSemaphore(value: 0)
        private var data = Data()

        init(_ handle: FileHandle) {
            let thread = Thread { [self] in
                data = handle.readDataToEndOfFile()
                done.signal()
            }
            thread.start()
        }

        func wait() -> String {
            done.wait()
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}
