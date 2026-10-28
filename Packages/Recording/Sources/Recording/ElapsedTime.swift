/// Formats the control bar's clock. Pure.
nonisolated enum ElapsedTime {
    /// `0:07`, `12:34`, `1:02:03`.
    static func string(_ duration: Duration) -> String {
        let total = max(0, Int(duration.components.seconds))
        let hours = total / 3600
        let minutes = total / 60 % 60
        let seconds = total % 60
        let tail = String(format: "%02d", seconds)
        return hours > 0 ? "\(hours):" + String(format: "%02d", minutes) + ":" + tail : "\(minutes):" + tail
    }

    /// `7 seconds`, `12 minutes 34 seconds`, for VoiceOver.
    static func spoken(_ duration: Duration) -> String {
        let total = max(0, Int(duration.components.seconds))
        let parts = [(total / 3600, "hour"), (total / 60 % 60, "minute"), (total % 60, "second")]
            .filter { $0.0 > 0 }
            .map { "\($0.0) \($0.1)\($0.0 == 1 ? "" : "s")" }
        return parts.isEmpty ? "0 seconds" : parts.joined(separator: " ")
    }
}
