import Foundation
import OrielCore

/// File names for captures, from a template such as `Oriel {date} at {time}` (Settings → Capture).
///
/// Tokens: `{date}` (2026-10-29), `{time}` (10.15.30, the way macOS names screenshots), `{kind}` (Area, Window…),
/// `{app}`, `{title}`, `{width}` and `{height}` (pixels). Unknown tokens stay as typed; `/` and `:`, which Finder
/// cannot show, become `-`.
nonisolated enum FilenameTemplate {
    static let defaultTemplate = "Oriel {date} at {time}"
    static let fallbackName = "Oriel Capture"
    static let tokens = ["{date}", "{time}", "{kind}", "{app}", "{title}", "{width}", "{height}"]
    /// File names may have 255 bytes; this leaves room for " 123.heic".
    static let maxLength = 200

    /// What the tokens are filled from.
    struct Context: Sendable {
        var date: Date
        var kind: CaptureKind
        var appName: String?
        var windowTitle: String?
        var pixelWidth: Int
        var pixelHeight: Int

        init(date: Date, kind: CaptureKind, appName: String? = nil, windowTitle: String? = nil, pixelWidth: Int, pixelHeight: Int) {
            self.date = date
            self.kind = kind
            self.appName = appName
            self.windowTitle = windowTitle
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
        }

        init(result: CaptureResult) {
            self.init(
                date: result.date,
                kind: result.kind,
                appName: result.appName,
                windowTitle: result.windowTitle,
                pixelWidth: result.image.width,
                pixelHeight: result.image.height
            )
        }
    }

    /// The file name (without extension) for `template`.
    static func render(_ template: String, context: Context, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: context.date)
        let date = "\(pad(parts.year, 4))-\(pad(parts.month, 2))-\(pad(parts.day, 2))"
        let time = "\(pad(parts.hour, 2)).\(pad(parts.minute, 2)).\(pad(parts.second, 2))"
        let values: [String: String] = [
            "{date}": date,
            "{time}": time,
            "{kind}": kindName(context.kind),
            "{app}": context.appName ?? "",
            "{title}": context.windowTitle ?? "",
            "{width}": String(context.pixelWidth),
            "{height}": String(context.pixelHeight),
        ]
        var name = template
        for (token, value) in values {
            name = name.replacingOccurrences(of: token, with: value)
        }
        return sanitize(name)
    }

    /// Makes `name` safe for a file name: no path separators or control characters, single spaces, no leading dot,
    /// at most `maxLength` characters, and never empty.
    static func sanitize(_ name: String) -> String {
        let replaced = name.map { character -> String in
            if character == "/" || character == ":" {
                return "-"
            }
            if character.isNewline || character.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) {
                return " "
            }
            return String(character)
        }.joined()
        let words = replaced.split(whereSeparator: { $0 == " " || $0 == "\t" })
        var cleaned = words.joined(separator: " ")
        while cleaned.hasPrefix(".") {
            cleaned.removeFirst()
        }
        cleaned = String(cleaned.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? fallbackName : cleaned
    }

    /// `folder/baseName.ext`, or `baseName 2.ext`, `baseName 3.ext`… when the name is taken.
    static func uniqueURL(in folder: URL, baseName: String, fileExtension: String, exists: (URL) -> Bool) -> URL {
        let first = folder.appending(path: "\(baseName).\(fileExtension)")
        guard exists(first) else { return first }
        for number in 2 ... 9999 {
            let candidate = folder.appending(path: "\(baseName) \(number).\(fileExtension)")
            if !exists(candidate) {
                return candidate
            }
        }
        return folder.appending(path: "\(baseName) \(UUID().uuidString).\(fileExtension)")
    }

    static func kindName(_ kind: CaptureKind) -> String {
        switch kind {
        case .area: "Area"
        case .window: "Window"
        case .screen: "Screen"
        case .scrolling: "Scrolling"
        case .imported: "Image"
        }
    }

    private static func pad(_ value: Int?, _ width: Int) -> String {
        let digits = String(value ?? 0)
        return String(repeating: "0", count: max(0, width - digits.count)) + digits
    }
}
