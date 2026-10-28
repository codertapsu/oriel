import Foundation
import OrielCore
import Testing

struct IPCMessageTests {
    @Test func requestsAndResponsesRoundTripAsJSON() throws {
        let request = IPCRequest(verb: "windows.focus", arguments: ["4242"], options: ["json": "true"])
        let decoded = try JSONDecoder().decode(IPCRequest.self, from: JSONEncoder().encode(request))
        #expect(decoded == request)
        #expect(decoded.flag("json"))
        #expect(!decoded.flag("all"))

        let failure = IPCResponse.failure(request, "no such window", status: 1)
        #expect(try JSONDecoder().decode(IPCResponse.self, from: JSONEncoder().encode(failure)) == failure)
    }

    @Test func windowInfoEncodesItsFrame() throws {
        let window = WindowInfo(
            id: 7,
            pid: 1,
            appName: "TextEdit",
            bundleID: "com.apple.TextEdit",
            title: "Notes",
            frame: CGRect(x: 1, y: 2, width: 3, height: 4),
            isMinimized: true
        )
        let decoded = try JSONDecoder().decode(WindowInfo.self, from: JSONEncoder().encode(window))
        #expect(decoded == window)
    }
}
