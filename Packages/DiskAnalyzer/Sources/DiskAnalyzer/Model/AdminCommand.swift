import Foundation

/// A command run with administrator rights through the system's own password prompt: `osascript` runs `do shell
/// script … with administrator privileges`, which asks in a standard dialog, so Oriel never sees the password and
/// needs no helper tool. Every argument is quoted for the shell, and the result for AppleScript, so a path with
/// spaces, quotes or `$` stays one argument.
nonisolated enum AdminCommand {
    static let osascript = "/usr/bin/osascript"

    /// `'…'`, with each `'` written as `'\''`.
    static func shellQuote(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    static func shellCommand(_ arguments: [String]) -> String {
        arguments.map(shellQuote).joined(separator: " ")
    }

    /// An AppleScript string literal.
    static func appleScriptString(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// The script to pass to `osascript -e`.
    static func appleScript(for arguments: [String], prompt: String) -> String {
        "do shell script \(appleScriptString(shellCommand(arguments))) with prompt \(appleScriptString(prompt)) "
            + "with administrator privileges"
    }
}
