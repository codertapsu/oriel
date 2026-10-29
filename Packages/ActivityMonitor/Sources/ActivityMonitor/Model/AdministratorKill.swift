import Foundation

/// Signals other users' processes through macOS's administrator prompt:
/// `osascript -e 'do shell script "/bin/kill -15 1234 5678" with administrator privileges'`, one prompt for all of them.
/// The script is built from integers only, the signal from the fixed list and pids above 1, so nothing a process name
/// or the user supplies reaches the shell.
nonisolated enum AdministratorKill {
    static let osascript = URL(fileURLWithPath: "/usr/bin/osascript")

    /// The AppleScript, or nil when there is no pid that could ever be signalled.
    static func script(signal: ProcessSignal, pids: [Int32]) -> String? {
        guard !pids.isEmpty, pids.allSatisfy({ $0 > 1 }) else { return nil }
        let list = pids.map(String.init).joined(separator: " ")
        return "do shell script \"/bin/kill -\(signal.number) \(list)\" with administrator privileges"
    }

    static func arguments(signal: ProcessSignal, pids: [Int32]) -> [String]? {
        script(signal: signal, pids: pids).map { ["-e", $0] }
    }

    /// osascript's error when the user cancels the password prompt (errAEUserCanceled).
    static func isCancellation(_ message: String) -> Bool {
        message.contains("-128") || message.localizedCaseInsensitiveContains("User canceled")
    }
}
