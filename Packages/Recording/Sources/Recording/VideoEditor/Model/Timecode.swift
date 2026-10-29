import Foundation

/// How the video editor writes times. Pure.
nonisolated enum Timecode {
    /// `0:07.25`, `12:34.50`, `1:02:03.00`: minutes and seconds to the hundredth, hours once there are any.
    static func string(_ seconds: Double) -> String {
        let hundredths = seconds.isFinite ? Int((max(seconds, 0) * 100).rounded(.down)) : 0
        let total = hundredths / 100
        let fraction = String(format: "%02d", hundredths % 100)
        let hours = total / 3600
        let minutes = total / 60 % 60
        let rest = String(format: "%02d", total % 60)
        if hours > 0 {
            return "\(hours):" + String(format: "%02d", minutes) + ":\(rest).\(fraction)"
        }
        return "\(minutes):\(rest).\(fraction)"
    }

    /// `0:07`, `1:02:03`: whole seconds, for the ruler.
    static func short(_ seconds: Double) -> String {
        let total = seconds.isFinite ? Int(max(seconds, 0).rounded(.down)) : 0
        let hours = total / 3600
        let minutes = total / 60 % 60
        let rest = String(format: "%02d", total % 60)
        return hours > 0 ? "\(hours):" + String(format: "%02d", minutes) + ":\(rest)" : "\(minutes):\(rest)"
    }

    /// `7.2 seconds`, `1 minute 2.5 seconds`, for VoiceOver.
    static func spoken(_ seconds: Double) -> String {
        let tenths = seconds.isFinite ? Int((max(seconds, 0) * 10).rounded()) : 0
        let hours = tenths / 36000
        let minutes = tenths / 600 % 60
        let rest = Double(tenths % 600) / 10
        var parts: [String] = []
        if hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        if minutes > 0 {
            parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")")
        }
        if rest > 0 || parts.isEmpty {
            let number = rest == rest.rounded() ? String(Int(rest)) : String(format: "%.1f", rest)
            parts.append("\(number) second\(rest == 1 ? "" : "s")")
        }
        return parts.joined(separator: " ")
    }
}
