import Foundation
import Testing

/// PLAN §13.1: the built app's Info.plist. The test host is Oriel.app, so `Bundle.main` is the app.
struct InfoPlistTests {
    private let info = Bundle.main.infoDictionary ?? [:]

    @Test func isAMenuBarAgentForMacOS26() {
        #expect(info["LSUIElement"] as? Bool == true)
        #expect(info["LSMinimumSystemVersion"] as? String == "26.0")
    }

    /// macOS keeps one permission entry per bundle ID, so a Debug build must not share the release's
    /// (docs/os-quirks.md). The test host is the Debug build.
    @Test func debugBuildsHaveTheirOwnIdentity() {
        #if DEBUG
            #expect(Bundle.main.bundleIdentifier == "com.codertapsu.oriel.debug")
            #expect(info["CFBundleDisplayName"] as? String == "Oriel Debug")
        #else
            #expect(Bundle.main.bundleIdentifier == "com.codertapsu.oriel")
            #expect(info["CFBundleDisplayName"] as? String == "Oriel")
        #endif
    }

    @Test func explainsTheMicrophoneAndTheCamera() {
        #expect((info["NSMicrophoneUsageDescription"] as? String)?.isEmpty == false)
        #expect((info["NSCameraUsageDescription"] as? String)?.isEmpty == false)
    }

    @Test func opensOrielURLsAndDocuments() {
        let urlTypes = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
        #expect(urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] } == ["oriel"])
        let exported = info["UTExportedTypeDeclarations"] as? [[String: Any]] ?? []
        #expect(exported.compactMap { $0["UTTypeIdentifier"] as? String } == ["com.codertapsu.oriel.document"])
    }

    @Test func allowsLocalModelServers() {
        let transport = info["NSAppTransportSecurity"] as? [String: Any] ?? [:]
        #expect(transport["NSAllowsLocalNetworking"] as? Bool == true)
        #expect(transport["NSAllowsArbitraryLoads"] == nil)
    }

    /// XcodeGen writes literal versions unless the Info.plist refers to the build settings (docs/RELEASING.md).
    @Test func takesItsVersionFromProjectYml() throws {
        let projectYml = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("project.yml")
        let text = try String(contentsOf: projectYml, encoding: .utf8)
        let match = try #require(text.firstMatch(of: /MARKETING_VERSION: *"?([0-9.]+)"?/))
        #expect(info["CFBundleShortVersionString"] as? String == String(match.1))
        #expect(Int(info["CFBundleVersion"] as? String ?? "") != nil)
    }
}
