import Foundation

/// How the window, its summary and the CLI write numbers: in the user's locale in the window, as macOS's Activity
/// Monitor does, and in a fixed one for `oriel top`, whose output scripts read. Unknown values are a dash.
nonisolated enum ActivityFormat {
    static let dash = "–"
    /// The CLI's locale: a point for decimals, no grouping surprises.
    static let posix = Locale(identifier: "en_US_POSIX")

    /// "12.3", one decimal, without the percent sign the column header already has.
    static func percent(_ value: Double?, locale: Locale = .current) -> String {
        guard let value, value.isFinite else { return dash }
        return value.formatted(.number.precision(.fractionLength(1)).grouping(.never).locale(locale))
    }

    /// "12.3 %".
    static func percentWithSign(_ value: Double?, locale: Locale = .current) -> String {
        guard let value, value.isFinite else { return dash }
        return percent(value, locale: locale) + " %"
    }

    /// Memory in binary units, as Activity Monitor shows it ("1.25 GB" for 1.25 × 2³⁰ bytes).
    static func memory(_ bytes: UInt64?, locale: Locale = .current) -> String {
        guard let bytes else { return dash }
        return Int64(clamping: bytes).formatted(.byteCount(style: .memory, spellsOutZero: false).locale(locale))
    }

    /// Amounts of data in decimal units, as Finder counts them.
    static func bytes(_ bytes: UInt64?, locale: Locale = .current) -> String {
        guard let bytes else { return dash }
        return Int64(clamping: bytes).formatted(.byteCount(style: .file, spellsOutZero: false).locale(locale))
    }

    /// "1.2 MB/s"; "0" for nothing, so idle rows stay quiet.
    static func rate(_ bytesPerSecond: Double?, locale: Locale = .current) -> String {
        guard let bytesPerSecond, bytesPerSecond.isFinite else { return dash }
        guard bytesPerSecond >= 0.5 else { return "0" }
        return Int64(bytesPerSecond.rounded()).formatted(.byteCount(style: .file, spellsOutZero: false).locale(locale)) + "/s"
    }

    /// CPU time as Activity Monitor writes it: "4.21", "12:03.27", "2:01:09.80".
    static func cpuTime(_ nanoseconds: UInt64?, locale: Locale = .current) -> String {
        guard let nanoseconds else { return dash }
        let hundredths = Int(clamping: nanoseconds / 10_000_000)
        let seconds = hundredths / 100
        let point = locale.decimalSeparator ?? "."
        let fraction = point + String(format: "%02ld", hundredths % 100)
        let hours = seconds / 3600
        let minutes = seconds / 60 % 60
        if hours > 0 {
            return String(format: "%ld:%02ld:%02ld", hours, minutes, seconds % 60) + fraction
        }
        if minutes > 0 {
            return String(format: "%ld:%02ld", minutes, seconds % 60) + fraction
        }
        return "\(seconds % 60)" + fraction
    }

    /// "350 mW", "1.25 W".
    static func power(_ watts: Double?, locale: Locale = .current) -> String {
        guard let watts, watts.isFinite else { return dash }
        if watts < 0.0005 {
            return "0"
        }
        if watts < 1 {
            return (watts * 1000).formatted(.number.precision(.fractionLength(0)).locale(locale)) + " mW"
        }
        return watts.formatted(.number.precision(.fractionLength(2)).locale(locale)) + " W"
    }

    /// "12", "1.5": per second, with a decimal only for small values.
    static func perSecond(_ value: Double?, locale: Locale = .current) -> String {
        guard let value, value.isFinite else { return dash }
        let digits = value < 10 && value > 0 ? 1 : 0
        return value.formatted(.number.precision(.fractionLength(digits)).locale(locale))
    }

    /// "2.13".
    static func decimal(_ value: Double?, digits: Int = 2, locale: Locale = .current) -> String {
        guard let value, value.isFinite else { return dash }
        return value.formatted(.number.precision(.fractionLength(digits)).locale(locale))
    }

    static func count(_ value: Int?, locale: Locale = .current) -> String {
        value.map { $0.formatted(.number.locale(locale)) } ?? dash
    }

    static func count(_ value: UInt64?, locale: Locale = .current) -> String {
        value.map { $0.formatted(.number.locale(locale)) } ?? dash
    }

    static func count(_ number: Int, _ singular: String, _ plural: String? = nil, locale: Locale = .current) -> String {
        "\(number.formatted(.number.locale(locale))) \(number == 1 ? singular : plural ?? singular + "s")"
    }

    /// "1 h 12 min", "8 min".
    static func minutes(_ minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
    }
}
