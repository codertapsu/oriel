import Foundation

/// Sizes, counts, dates and shares as the window shows them: sizes as Finder counts them (1 KB = 1,000 bytes).
nonisolated enum DiskFormat {
    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    /// "1 file", "1,204 files".
    static func count(_ number: Int, _ noun: String, plural: String? = nil) -> String {
        let word = number == 1 ? noun : plural ?? noun + "s"
        return "\(number.formatted()) \(word)"
    }

    static func smallFiles(_ number: Int) -> String {
        number == 1 ? "1 smaller file" : "\(number.formatted()) smaller files"
    }

    /// "34 %", or "< 1 %" for a share too small to round up.
    static func share(_ part: Int64, of whole: Int64) -> String {
        guard whole > 0, part > 0 else { return "0 %" }
        let fraction = Double(part) / Double(whole)
        if fraction < 0.01 {
            return "< 1 %"
        }
        return fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// A date and time short enough for a list column.
    static func compact(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .numeric, time: .shortened)
    }

    static func day(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    /// "3 months ago", for how long a file has not been used.
    static func relative(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(.relative(presentation: .named, unitsStyle: .wide))
    }

    static func duration(_ duration: Duration) -> String {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        if seconds < 1 {
            return "less than a second"
        }
        if seconds < 60 {
            return count(Int(seconds.rounded()), "second")
        }
        return count(Int((seconds / 60).rounded()), "minute")
    }

    /// "+3.2 GB" or "−400 MB".
    static func change(_ delta: Int64) -> String {
        delta >= 0 ? "+" + bytes(delta) : "−" + bytes(-delta)
    }

    static func days(_ days: Int) -> String {
        switch days {
        case 30: "a month"
        case 90: "3 months"
        case 180: "6 months"
        case 365: "a year"
        case 730: "2 years"
        case 1825: "5 years"
        default: count(days, "day")
        }
    }
}
