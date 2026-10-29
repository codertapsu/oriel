import Foundation

/// The one simulator action Oriel offers: `xcrun simctl delete unavailable`, which removes simulators whose runtime is
/// no longer installed, the way Xcode's own cleanup does. Offered only where simulators exist, so `xcrun` never asks to
/// install the developer tools.
nonisolated enum Simulators {
    static let xcrun = "/usr/bin/xcrun"

    static func exist(home: String = NSHomeDirectory()) -> Bool {
        FileManager.default.fileExists(atPath: home + "/Library/Developer/CoreSimulator/Devices")
    }

    static func deleteUnavailable() async -> ProcessRunner.Result {
        await ProcessRunner.run(xcrun, ["simctl", "delete", "unavailable"])
    }
}
