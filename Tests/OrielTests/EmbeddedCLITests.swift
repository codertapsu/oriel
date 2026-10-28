import Foundation
import Testing

/// The CLI target has no test bundle of its own, so this runs the copy embedded in the test host, `Oriel.app`.
struct EmbeddedCLITests {
    @Test func embeddedCLIPrintsUsage() throws {
        let process = Process()
        process.executableURL = Bundle.main.bundleURL.appending(path: "Contents/Helpers/oriel")
        process.arguments = ["--help"]
        let stdout = Pipe()
        process.standardOutput = stdout
        try process.run()
        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(output?.hasPrefix("usage: oriel") == true)
    }
}
