import Darwin
import Foundation
import IPC
import OrielCore
import Testing

struct IPCTests {
    /// Short: a Unix socket path must fit in 104 bytes.
    private func socketURL() -> URL {
        URL(fileURLWithPath: "/tmp/oriel-test-\(UUID().uuidString.prefix(8)).sock")
    }

    @Test func aRequestReachesTheHandlerAndItsResponseComesBack() throws {
        let url = socketURL()
        let server = IPCServer(socketURL: url) { request in
            IPCResponse.ok(request, "\(request.verb) \(request.arguments.joined(separator: ",")) json=\(request.flag("json"))")
        }
        try server.start()
        defer { server.stop() }
        let request = IPCRequest(verb: "windows.focus", arguments: ["42"], options: ["json": "true"])
        let response = try IPCClient.send(request, to: url, timeout: 5)
        #expect(response.status == 0)
        #expect(response.output == "windows.focus 42 json=true")
    }

    @Test func theSocketIsPrivateToItsUser() throws {
        let url = socketURL()
        let server = IPCServer(socketURL: url) { IPCResponse.ok($0) }
        try server.start()
        defer { server.stop() }
        var info = stat()
        #expect(stat(url.path, &info) == 0)
        #expect(info.st_mode & 0o777 == 0o600)
    }

    @Test func aStaleSocketFileDoesNotBlockStartup() throws {
        let url = socketURL()
        FileManager.default.createFile(atPath: url.path, contents: Data("stale".utf8))
        let server = IPCServer(socketURL: url) { IPCResponse.ok($0, "fresh") }
        try server.start()
        defer { server.stop() }
        #expect(try IPCClient.send(IPCRequest(verb: "ping"), to: url, timeout: 5).output == "fresh")
    }

    @Test func noServerMeansTheAppIsNotRunning() {
        #expect(throws: IPCError.appNotRunning) {
            try IPCClient.send(IPCRequest(verb: "ping"), to: socketURL(), timeout: 1)
        }
    }

    @Test func concurrentClientsAllGetTheirOwnAnswers() async throws {
        let url = socketURL()
        let server = IPCServer(socketURL: url) { request in
            try? await Task.sleep(for: .milliseconds(20))
            return IPCResponse.ok(request, request.arguments.first ?? "")
        }
        try server.start()
        defer { server.stop() }
        let answers = try await withThrowingTaskGroup(of: String.self) { group in
            for index in 0 ..< 8 {
                group.addTask { try IPCClient.send(IPCRequest(verb: "echo", arguments: ["\(index)"]), to: url, timeout: 5).output }
            }
            return try await group.reduce(into: Set<String>()) { $0.insert($1) }
        }
        #expect(answers == Set((0 ..< 8).map(String.init)))
    }
}
