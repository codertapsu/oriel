import Foundation

/// Test fixtures kept in the repository: `<package>/Tests/Fixtures/<name>/` (PLAN §14.4), next to the test targets and
/// outside them, so SwiftPM does not bundle them.
public enum Fixtures {
    /// The fixtures folder `name` of the package whose test file is `filePath` (`<package>/Tests/<target>/…`).
    public static func folder(_ name: String, filePath: String) -> URL {
        var url = URL(fileURLWithPath: filePath).deletingLastPathComponent()
        while url.lastPathComponent != "Tests", url.pathComponents.count > 1 {
            url.deleteLastPathComponent()
        }
        return url.appending(path: "Fixtures/\(name)", directoryHint: .isDirectory)
    }
}
