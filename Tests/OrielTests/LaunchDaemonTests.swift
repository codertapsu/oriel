import Foundation
import Testing

/// Disk Space Analyzer's helper (PLAN §7.10 item 17): the built app carries its launchd property list, named after the
/// app's bundle ID, so a Debug build's helper never takes the release's name (CLAUDE.md rule 14), and pointing at the
/// app's own executable. The test host is the app.
struct LaunchDaemonTests {
    @Test func theAppCarriesTheDiskReadersPropertyList() throws {
        let bundleID = try #require(Bundle.main.bundleIdentifier)
        let label = bundleID + ".disk-reader"
        let url = Bundle.main.bundleURL.appending(path: "Contents/Library/LaunchDaemons/\(label).plist")
        let plist = try #require(NSDictionary(contentsOf: url) as? [String: Any])
        let executable = try #require(Bundle.main.executableURL?.lastPathComponent)
        #expect(plist["Label"] as? String == label)
        #expect(plist["BundleProgram"] as? String == "Contents/MacOS/\(executable)")
        #expect((plist["MachServices"] as? [String: Bool])?[label] == true)
        #expect(plist["AssociatedBundleIdentifiers"] as? [String] == [bundleID])
        #expect(plist["Program"] == nil)
        #expect(plist["ProgramArguments"] == nil)
    }
}
