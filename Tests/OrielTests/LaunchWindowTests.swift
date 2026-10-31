import Foundation
@testable import Oriel
import Testing

/// A launch the user made opens Settings a moment after starting, unless Oriel is asked to do something else first, as an
/// App Intent asks just after the launch it caused (PLAN §10.1).
@MainActor
struct LaunchWindowTests {
    @Test func theWindowOpensAfterTheDelay() async throws {
        let window = LaunchWindow()
        var opened = 0
        window.schedule(after: .milliseconds(10)) { opened += 1 }
        #expect(window.isPending && opened == 0)
        try await Task.sleep(for: .milliseconds(200))
        #expect(opened == 1 && !window.isPending)
    }

    @Test func aRequestBeforeItKeepsItClosed() async throws {
        let window = LaunchWindow()
        var opened = 0
        window.schedule(after: .milliseconds(50)) { opened += 1 }
        window.cancel()
        try await Task.sleep(for: .milliseconds(200))
        #expect(opened == 0 && !window.isPending)
    }
}
