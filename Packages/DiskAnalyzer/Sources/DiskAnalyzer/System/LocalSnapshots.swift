import Foundation

/// Local Time Machine snapshots, through `tmutil`. Listing works without privileges. Thinning is tried as the user
/// first; if macOS wants an administrator, it runs again through the system's own password prompt
/// (`AdminCommand`). macOS thins these snapshots by itself when space runs low, so this only makes that happen now.
nonisolated enum LocalSnapshots {
    static let tmutil = "/usr/bin/tmutil"

    enum ThinResult: Sendable, Equatable {
        case thinned(Int)
        case failed(String)
        case cancelled
    }

    /// The snapshots of the volume mounted at `volume`; nil when `tmutil` could not say.
    static func list(volume: String) async -> [LocalSnapshotList.Snapshot]? {
        let result = await ProcessRunner.run(tmutil, ["listlocalsnapshots", volume])
        guard result.succeeded else { return nil }
        return LocalSnapshotList.snapshots(fromList: result.output)
    }

    /// Asks macOS to free up to `bytes` by removing local snapshots, at the highest urgency.
    static func thin(volume: String, bytes: Int64) async -> ThinResult {
        let arguments = ["thinlocalsnapshots", volume, String(max(1, bytes)), "4"]
        let plain = await ProcessRunner.run(tmutil, arguments)
        if plain.succeeded {
            return .thinned(LocalSnapshotList.thinnedCount(fromThin: plain.output))
        }
        let script = AdminCommand.appleScript(
            for: [tmutil] + arguments,
            prompt: "Oriel wants to remove local Time Machine snapshots to free space."
        )
        let elevated = await ProcessRunner.run(AdminCommand.osascript, ["-e", script])
        if elevated.succeeded {
            return .thinned(LocalSnapshotList.thinnedCount(fromThin: elevated.output))
        }
        // osascript reports the user's Cancel as error -128.
        if elevated.error.contains("-128") {
            return .cancelled
        }
        let message = elevated.error.isEmpty ? plain.error : elevated.error
        return .failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
