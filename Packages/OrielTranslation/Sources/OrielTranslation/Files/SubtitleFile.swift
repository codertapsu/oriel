import Foundation

/// Reads and writes SRT and WebVTT subtitles (PLAN §17). Reading is forgiving: a byte-order mark, CRLF or CR line
/// ends, missing or wrong cue numbers, `.` or `,` before the milliseconds, timings without hours, stray blank lines
/// and WebVTT comments. Timing is kept to the millisecond; cues are numbered again when written.
enum SubtitleFile {
    struct Parsed: Sendable, Equatable {
        var cues: [SubtitleCue]
        /// WebVTT's header and the STYLE and REGION blocks before the first cue, written back to WebVTT as they were.
        var header: String?
    }

    // MARK: - Reading

    static func parse(_ text: String) -> Parsed {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        var cues: [SubtitleCue] = []
        var preamble: [String] = []
        for block in blocks(of: normalized) {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            guard let timingIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                // WEBVTT, STYLE, REGION and NOTE blocks before the cues; later NOTE comments are dropped.
                if cues.isEmpty {
                    preamble.append(block)
                }
                continue
            }
            guard let (start, end, settings) = timing(lines[timingIndex]) else { continue }
            let identifier = timingIndex > 0 ? lines[timingIndex - 1].trimmingCharacters(in: .whitespaces) : nil
            let text = lines[(timingIndex + 1)...].joined(separator: "\n").trimmingCharacters(in: .newlines)
            cues.append(SubtitleCue(
                identifier: identifier.flatMap { $0.isEmpty || Int($0) != nil ? nil : $0 },
                start: start,
                end: end,
                settings: settings,
                rawText: text
            ))
        }
        let header = preamble.first?.hasPrefix("WEBVTT") == true ? preamble.joined(separator: "\n\n") : nil
        return Parsed(cues: cues, header: header)
    }

    /// Blocks separated by one or more blank lines.
    private static func blocks(of text: String) -> [String] {
        var blocks: [String] = []
        var current: [Substring] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                if !current.isEmpty {
                    blocks.append(current.joined(separator: "\n"))
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty {
            blocks.append(current.joined(separator: "\n"))
        }
        return blocks
    }

    /// `00:00:01,000 --> 00:00:04,000 align:start` → start, end, settings.
    static func timing(_ line: String) -> (Int, Int, String)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2, let start = milliseconds(parts[0]) else { return nil }
        let rest = parts[1].split(separator: " ", omittingEmptySubsequences: true)
        guard let first = rest.first, let end = milliseconds(String(first)) else { return nil }
        return (start, end, rest.dropFirst().joined(separator: " "))
    }

    /// `hh:mm:ss,mmm`, `hh:mm:ss.mmm`, `mm:ss.mmm` or `hh:mm:ss` in milliseconds.
    static func milliseconds(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let main: Substring
        var fraction = 0
        if let separator = trimmed.lastIndex(where: { $0 == "," || $0 == "." }) {
            main = trimmed[..<separator]
            let digits = trimmed[trimmed.index(after: separator)...]
            guard !digits.isEmpty, digits.count <= 3, let value = Int(digits) else { return nil }
            fraction = value * [1, 100, 10, 1][digits.count]
        } else {
            main = Substring(trimmed)
        }
        let fields = main.split(separator: ":", omittingEmptySubsequences: false)
        let values = fields.compactMap { Int($0) }
        guard (2 ... 3).contains(fields.count), values.count == fields.count, values.allSatisfy({ $0 >= 0 }) else { return nil }
        let (hours, minutes, seconds) = values.count == 3 ? (values[0], values[1], values[2]) : (0, values[0], values[1])
        guard minutes < 60, seconds < 60 else { return nil }
        return ((hours * 60 + minutes) * 60 + seconds) * 1000 + fraction
    }

    // MARK: - Writing

    /// SRT: numbered cues, `hh:mm:ss,mmm`, an SRT position tag kept in front of the text.
    static func srt(_ cues: [(cue: SubtitleCue, text: String)]) -> String {
        var output = ""
        for (index, item) in cues.enumerated() {
            let tag = item.cue.leadingTag.hasPrefix("{") ? item.cue.leadingTag : ""
            output += "\(index + 1)\n"
            output += "\(timestamp(item.cue.start, separator: ",")) --> \(timestamp(item.cue.end, separator: ","))\n"
            output += tag + item.text + "\n\n"
        }
        return output
    }

    /// WebVTT: the header of a WebVTT source (or `WEBVTT`), identifiers, settings and voices kept, text escaped.
    static func vtt(_ cues: [(cue: SubtitleCue, text: String)], header: String?) -> String {
        var output = (header ?? "WEBVTT") + "\n\n"
        for item in cues {
            if let identifier = item.cue.identifier {
                output += identifier + "\n"
            }
            var timing = "\(timestamp(item.cue.start, separator: ".")) --> \(timestamp(item.cue.end, separator: "."))"
            let settings = vttSettings(item.cue.settings)
            if !settings.isEmpty {
                timing += " " + settings
            }
            let voice = item.cue.leadingTag.hasPrefix("<v") ? item.cue.leadingTag : ""
            output += timing + "\n" + voice + SubtitleMarkup.escapedForVTT(item.text) + "\n\n"
        }
        return output
    }

    /// The WebVTT cue settings among `settings`; SRT's `X1:… Y2:…` coordinates are not among them.
    static func vttSettings(_ settings: String) -> String {
        let names: Set = ["vertical", "line", "position", "size", "align", "region"]
        return settings.split(separator: " ")
            .filter { setting in setting.split(separator: ":").first.map { names.contains(String($0)) } ?? false }
            .joined(separator: " ")
    }

    /// `01:02:03,456` (SRT) or `01:02:03.456` (WebVTT).
    static func timestamp(_ milliseconds: Int, separator: String) -> String {
        let value = max(0, milliseconds)
        let hours = value / 3_600_000
        let minutes = value / 60000 % 60
        let seconds = value / 1000 % 60
        return String(format: "%02d:%02d:%02d%@%03d", hours, minutes, seconds, separator, value % 1000)
    }
}
