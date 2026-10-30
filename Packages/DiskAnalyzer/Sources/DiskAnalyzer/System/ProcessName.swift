import Darwin
import Foundation

/// Names a process as Activity Monitor does (PLAN §7.10 item 19): an app by its bundle's name, anything else by its
/// executable's. Public libproc calls, from any thread.
nonisolated enum ProcessName {
    /// The app a process belongs to: the outermost app bundle its executable is in, so an app's helpers (Google Chrome
    /// Helper, inside Google Chrome) count as the app.
    static func app(of pid: Int32) -> (name: String, bundleID: String)? {
        guard let path = executablePath(of: pid), path.contains(".app/Contents/"), let range = path.range(of: ".app/") else { return nil }
        let bundlePath = String(path[..<range.lowerBound]) + ".app"
        guard let bundle = Bundle(path: bundlePath), let bundleID = bundle.bundleIdentifier else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? (bundlePath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        return (name, bundleID)
    }

    /// The executable's name, else "process <pid>".
    static func name(of pid: Int32) -> String {
        if let path = executablePath(of: pid) {
            return (path as NSString).lastPathComponent
        }
        var buffer = [CChar](repeating: 0, count: 256)
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return "process \(pid)" }
        return text(buffer) ?? "process \(pid)"
    }

    static func executablePath(of pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return text(buffer)
    }

    /// The C string at the start of `buffer`.
    private static func text(_ buffer: [CChar]) -> String? {
        String(bytes: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, encoding: .utf8)
    }
}
