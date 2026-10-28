// The `oriel` command. Arguments are parsed by hand (IPC's CommandParser); every command is answered by the
// running app over its Unix socket (PLAN §7.1.8).

import Foundation
import IPC
import OrielCore

func fail(_ message: String, status: Int32) -> Never {
    FileHandle.standardError.write(Data("oriel: \(message)\n".utf8))
    exit(status)
}

do {
    switch try CommandParser.parse(Array(CommandLine.arguments.dropFirst())) {
    case .help:
        print(Usage.text)
    case .version:
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        print("oriel \(version) (\(build))")
    case let .request(request, timeout):
        let response = try IPCClient.send(request, timeout: timeout)
        if !response.output.isEmpty {
            print(response.output, terminator: response.output.hasSuffix("\n") ? "" : "\n")
        }
        if let error = response.error, !error.isEmpty {
            FileHandle.standardError.write(Data("oriel: \(error)\n".utf8))
        }
        exit(response.status)
    }
} catch let error as CommandParser.ParseError {
    fail("\(error.message)\n\n\(Usage.text)", status: 64) // EX_USAGE
} catch IPCError.appNotRunning {
    fail("Oriel is not running. Start it with `open -a Oriel`, then try again.", status: 69) // EX_UNAVAILABLE
} catch {
    fail(error.localizedDescription, status: 1)
}
