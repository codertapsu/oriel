import AppKit
import Foundation
@testable import Oriel
import Testing

@MainActor
struct AppDelegateTests {
    /// Launched to open a file or URL, Oriel is asked to open it before `applicationDidFinishLaunching`, when nothing
    /// has started: it waits for Oriel to start instead of being dropped.
    @Test func whatOrielIsLaunchedToOpenWaitsUntilItHasStarted() throws {
        let delegate = AppDelegate()
        let file = URL(fileURLWithPath: "/tmp/Shot.oriel")
        let route = try #require(URL(string: "oriel://disk"))
        delegate.application(NSApplication.shared, open: [file, route])
        #expect(delegate.pendingURLs == [file, route])
    }
}
