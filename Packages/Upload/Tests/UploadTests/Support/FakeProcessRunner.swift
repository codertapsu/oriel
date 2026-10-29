import Foundation
import Synchronization
@testable import Upload

/// Stands in for `/usr/bin/sftp`: records what it was asked to run, with the batch script and the file it pointed
/// at, and answers with a canned result.
final class FakeProcessRunner: ProcessRunning {
    struct Run: Sendable {
        let executable: URL
        let arguments: [String]
        let input: String
        /// What the batch's `put` pointed at, read while the run lasted (Oriel removes its link afterwards).
        let uploadedBytes: Data?
    }

    private let result: ProcessResult
    private let runs = Mutex<[Run]>([])

    init(_ result: ProcessResult) {
        self.result = result
    }

    var recorded: [Run] {
        runs.withLock { $0 }
    }

    func run(_ executable: URL, arguments: [String], input: Data) async throws -> ProcessResult {
        let script = input.utf8Text
        let local = script.split(separator: "\n").first { $0.hasPrefix("put ") }.flatMap { line in
            line.split(separator: "\"").dropFirst().first.map(String.init)
        }
        let bytes = local.flatMap { FileManager.default.contents(atPath: $0) }
        runs.withLock { $0.append(Run(executable: executable, arguments: arguments, input: script, uploadedBytes: bytes)) }
        return result
    }
}
