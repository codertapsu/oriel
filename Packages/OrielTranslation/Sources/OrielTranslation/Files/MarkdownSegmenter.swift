import Foundation

/// Splits Markdown into the blocks a translation keeps (PLAN §17). Headings, paragraphs, list items and quotes are
/// translated, with their markers set aside (`## `, `- `, `1. `, `> `, `- [ ] `) so the export rebuilds the same
/// structure. Code (fenced or indented), tables, HTML blocks, rules and front matter are kept as they are. Inline
/// markup (links, emphasis, code spans) goes to the provider with the text: language models are told to keep it,
/// and the other providers usually do.
enum MarkdownSegmenter {
    static func segments(_ text: String, firstID: Int = 1) -> [DocumentSegment] {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var reader = Reader(lines: lines, builder: Builder(nextID: firstID))
        reader.read()
        return reader.builder.segments
    }

    /// Collects segments with fresh ids.
    fileprivate struct Builder {
        var segments: [DocumentSegment] = []
        var nextID: Int

        mutating func text(_ text: String, prefix: String, endsBlock: Bool) {
            guard !text.isEmpty else { return }
            segments.append(DocumentSegment(id: nextID, text: text, prefix: prefix, endsBlock: endsBlock))
            nextID += 1
        }

        mutating func verbatim(_ lines: ArraySlice<String>, endsBlock: Bool) {
            segments.append(DocumentSegment(id: nextID, text: "", verbatim: lines.joined(separator: "\n"), endsBlock: endsBlock))
            nextID += 1
        }
    }

    /// A list item or quote marker at the start of a line.
    fileprivate struct Marker {
        /// Everything before the content: indentation, `>`s, the bullet or number, a task box.
        let prefix: String
        let content: String
        /// The `>` part alone, to tell which quote a line belongs to.
        let quote: String
        let isListItem: Bool
    }

    fileprivate struct Reader {
        let lines: [String]
        var builder: Builder
        var index = 0
        var lastWasListItem = false

        mutating func read() {
            readFrontMatter()
            while index < lines.count {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    index += 1
                    continue
                }
                if readVerbatimBlock(line, trimmed) {
                    lastWasListItem = false
                    continue
                }
                if let heading = MarkdownSegmenter.atxHeading(trimmed) {
                    builder.text(heading.text, prefix: heading.prefix, endsBlock: isBlank(index + 1))
                    index += 1
                    lastWasListItem = false
                    continue
                }
                if let marker = MarkdownSegmenter.marker(line) {
                    readMarked(marker)
                    continue
                }
                readParagraph(trimmed)
            }
        }

        private func isBlank(_ index: Int) -> Bool {
            index >= lines.count || lines[index].trimmingCharacters(in: .whitespaces).isEmpty
        }

        /// Whether the code block that has reached `end` goes on: the next line is indented too, or blank with an
        /// indented line after it.
        private func continuesIndentedCode(after end: Int) -> Bool {
            let next = end + 1
            guard next < lines.count else { return false }
            if MarkdownSegmenter.indentation(of: lines[next]) >= 4 {
                return true
            }
            return isBlank(next) && next + 1 < lines.count && !isBlank(next + 1) && MarkdownSegmenter.indentation(of: lines[next + 1]) >= 4
        }

        private mutating func readFrontMatter() {
            guard lines.first?.trimmingCharacters(in: .whitespaces) == "---",
                  let end = lines.indices.dropFirst()
                      .first(where: { ["---", "..."].contains(lines[$0].trimmingCharacters(in: .whitespaces)) })
            else { return }
            builder.verbatim(lines[0 ... end], endsBlock: true)
            index = end + 1
        }

        /// Fenced and indented code, HTML blocks, tables and rules.
        private mutating func readVerbatimBlock(_ line: String, _ trimmed: String) -> Bool {
            let start = index
            var end: Int
            if let fence = MarkdownSegmenter.fence(trimmed) {
                end = index + 1
                while end < lines.count, !MarkdownSegmenter.closes(lines[end], fence: fence) {
                    end += 1
                }
                end = min(end, lines.count - 1)
            } else if MarkdownSegmenter.indentation(of: line) >= 4, !lastWasListItem, start == 0 || isBlank(start - 1) {
                end = index
                while continuesIndentedCode(after: end) {
                    end += 1
                }
            } else if MarkdownSegmenter.startsHTMLBlock(trimmed) {
                end = index
                while !isBlank(end + 1) {
                    end += 1
                }
            } else if MarkdownSegmenter.startsTable(lines, at: index) {
                end = index
                while end + 1 < lines.count, lines[end + 1].contains("|"), !isBlank(end + 1) {
                    end += 1
                }
            } else if MarkdownSegmenter.isThematicBreak(trimmed) {
                end = index
            } else {
                return false
            }
            builder.verbatim(lines[start ... end], endsBlock: isBlank(end + 1))
            index = end + 1
            return true
        }

        /// A list item with its continuation lines, or the lines of one quote paragraph.
        private mutating func readMarked(_ marker: Marker) {
            var parts = [marker.content]
            var end = index + 1
            while end < lines.count, !isBlank(end) {
                let next = lines[end]
                let trimmed = next.trimmingCharacters(in: .whitespaces)
                if MarkdownSegmenter.startsBlock(trimmed, lines: lines, at: end) {
                    break
                }
                if let nextMarker = MarkdownSegmenter.marker(next) {
                    guard !marker.isListItem, !nextMarker.isListItem, nextMarker.quote == marker.quote,
                          MarkdownSegmenter.atxHeading(nextMarker.content.trimmingCharacters(in: .whitespaces)) == nil
                    else { break }
                    parts.append(nextMarker.content)
                } else {
                    parts.append(trimmed)
                }
                end += 1
            }
            builder.text(LineJoiner.join(parts), prefix: marker.prefix, endsBlock: isBlank(end))
            index = end
            lastWasListItem = marker.isListItem
        }

        /// Lines up to a blank line or the next block; an underline of `=` or `-` makes it a heading.
        private mutating func readParagraph(_ first: String) {
            var parts = [first]
            var prefix = ""
            var end = index + 1
            while end < lines.count, !isBlank(end) {
                let trimmed = lines[end].trimmingCharacters(in: .whitespaces)
                if let level = MarkdownSegmenter.setextLevel(trimmed) {
                    prefix = String(repeating: "#", count: level) + " "
                    end += 1
                    break
                }
                if MarkdownSegmenter.startsBlock(trimmed, lines: lines, at: end) || MarkdownSegmenter.marker(lines[end]) != nil {
                    break
                }
                parts.append(trimmed)
                end += 1
            }
            // A paragraph indented under a list item belongs to that item: keep its indentation.
            let indent = lastWasListItem ? String(repeating: " ", count: MarkdownSegmenter.indentation(of: lines[index])) : ""
            builder.text(LineJoiner.join(parts), prefix: prefix.isEmpty ? indent : prefix, endsBlock: isBlank(end))
            index = end
            if indent.isEmpty {
                lastWasListItem = false
            }
        }
    }

    // MARK: - Line tests

    static func indentation(of line: String) -> Int {
        var width = 0
        for character in line {
            if character == " " {
                width += 1
            } else if character == "\t" {
                width += 4
            } else {
                break
            }
        }
        return width
    }

    /// `## Title ##` → (`## `, `Title`).
    static func atxHeading(_ trimmed: String) -> (prefix: String, text: String)? {
        let hashes = trimmed.prefix { $0 == "#" }
        guard (1 ... 6).contains(hashes.count) else { return nil }
        let rest = trimmed.dropFirst(hashes.count)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") {
            text.removeLast()
        }
        return ("\(hashes) ", text.trimmingCharacters(in: .whitespaces))
    }

    /// The fence characters of a code fence opening (```` ``` ```` or `~~~`, three or more).
    static func fence(_ trimmed: String) -> String? {
        for character in ["`", "~"] {
            let run = trimmed.prefix { String($0) == character }
            if run.count >= 3 {
                return String(run)
            }
        }
        return nil
    }

    static func closes(_ line: String, fence: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let character = fence.first else { return false }
        return trimmed.count >= fence.count && trimmed.allSatisfy { $0 == character }
    }

    static func isThematicBreak(_ trimmed: String) -> Bool {
        let marks = trimmed.filter { $0 != " " && $0 != "\t" }
        guard marks.count >= 3, let first = marks.first, "-*_".contains(first) else { return false }
        return marks.allSatisfy { $0 == first }
    }

    static func setextLevel(_ trimmed: String) -> Int? {
        guard trimmed.count >= 2 else { return nil }
        if trimmed.allSatisfy({ $0 == "=" }) {
            return 1
        }
        return trimmed.allSatisfy { $0 == "-" } ? 2 : nil
    }

    private static let htmlBlockTags: Set<String> = [
        "address", "article", "aside", "audio", "blockquote", "center", "details", "dialog", "div", "dl", "fieldset",
        "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "iframe", "img",
        "main", "nav", "ol", "p", "picture", "pre", "script", "section", "style", "summary", "table", "ul", "video",
    ]

    static func startsHTMLBlock(_ trimmed: String) -> Bool {
        guard trimmed.hasPrefix("<") else { return false }
        if trimmed.hasPrefix("<!--") {
            return true
        }
        let name = trimmed.dropFirst().drop { $0 == "/" }.prefix { $0.isLetter || $0.isNumber }.lowercased()
        return htmlBlockTags.contains(name)
    }

    /// A row starting with `|`, or a row followed by a delimiter row (`--- | :---:`).
    static func startsTable(_ lines: [String], at index: Int) -> Bool {
        let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }
        if trimmed.hasPrefix("|") {
            return true
        }
        guard index + 1 < lines.count else { return false }
        let delimiter = lines[index + 1].trimmingCharacters(in: .whitespaces)
        return delimiter.contains("|") && delimiter.contains("-") && delimiter.allSatisfy { "|-: ".contains($0) }
    }

    /// Whether a line starts a block that ends the paragraph or item before it.
    static func startsBlock(_ trimmed: String, lines: [String], at index: Int) -> Bool {
        fence(trimmed) != nil || atxHeading(trimmed) != nil || startsHTMLBlock(trimmed) || startsTable(lines, at: index)
            || isThematicBreak(trimmed)
    }

    /// A list item (`- `, `* `, `+ `, `1. `, `1) `, with an optional task box) or quote (`> `) at the start of a line.
    fileprivate static func marker(_ line: String) -> Marker? {
        var rest = Substring(line)
        let indent = rest.prefix { $0 == " " || $0 == "\t" }
        rest = rest.dropFirst(indent.count)
        var quote = ""
        while rest.first == ">" {
            rest = rest.dropFirst()
            quote += ">"
            if rest.first == " " {
                rest = rest.dropFirst()
                quote += " "
            }
        }
        var bullet = ""
        if let first = rest.first, "-*+".contains(first), rest.dropFirst().first == " " {
            bullet = "\(first) "
            rest = rest.dropFirst(2)
        } else {
            let digits = rest.prefix { $0.isASCII && $0.isNumber }
            let after = rest.dropFirst(digits.count)
            if (1 ... 9).contains(digits.count), let mark = after.first, mark == "." || mark == ")", after.dropFirst().first == " " {
                bullet = "\(digits)\(mark) "
                rest = after.dropFirst(2)
            }
        }
        guard !quote.isEmpty || !bullet.isEmpty else { return nil }
        if !bullet.isEmpty {
            for box in ["[ ] ", "[x] ", "[X] "] where rest.hasPrefix(box) {
                bullet += box
                rest = rest.dropFirst(box.count)
            }
        }
        let spaces = rest.prefix { $0 == " " }
        return Marker(
            prefix: String(indent) + quote + bullet + spaces,
            content: String(rest.dropFirst(spaces.count)),
            quote: quote,
            isListItem: !bullet.isEmpty
        )
    }
}
