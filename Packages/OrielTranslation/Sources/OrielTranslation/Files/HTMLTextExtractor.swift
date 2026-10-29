import Foundation

/// Reads the text of an HTML file as blocks (PLAN §17), without WebKit: `NSAttributedString`'s HTML import needs the
/// main thread and would load the page's images, styles and scripts from the network. Headings, paragraphs, list
/// items, quotes and table cells become segments, with Markdown markers for the export; `<pre>` becomes a code block
/// kept as it is; scripts, styles, the head and embedded content are skipped; entities are decoded.
enum HTMLTextExtractor {
    static func segments(_ html: String, firstID: Int = 1) -> [DocumentSegment] {
        var reader = Reader(html: html, nextID: firstID)
        reader.read()
        return reader.segments
    }

    private static let skipped: Set<String> = [
        "script",
        "style",
        "head",
        "noscript",
        "template",
        "svg",
        "iframe",
        "object",
        "canvas",
        "math",
    ]
    private static let blocks: Set<String> = [
        "address", "article", "aside", "blockquote", "body", "caption", "center", "dd", "details", "dialog", "div", "dl", "dt",
        "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hgroup", "hr",
        "html", "legend", "li", "main", "nav", "ol", "p", "section", "summary", "table", "tbody", "td", "tfoot", "th",
        "thead", "tr", "ul",
    ]

    private struct Open {
        let name: String
        /// For `li`: `- ` or `3. `; counts items for `ol`.
        var marker = ""
        var count = 0
    }

    private struct Reader {
        let html: String
        var nextID: Int
        var segments: [DocumentSegment] = []
        private var index: String.Index
        private var stack: [Open] = []
        private var text = ""
        private var skipping: String?
        private var preformatted: String?

        init(html: String, nextID: Int) {
            self.html = html
            self.nextID = nextID
            index = html.startIndex
        }

        mutating func read() {
            while index < html.endIndex {
                if html[index] == "<" {
                    readMarkup()
                } else {
                    let end = html[index...].firstIndex(of: "<") ?? html.endIndex
                    if skipping == nil {
                        let chunk = HTMLEntities.decode(String(html[index ..< end]))
                        if preformatted != nil {
                            preformatted? += chunk
                        } else {
                            text += chunk
                        }
                    }
                    index = end
                }
            }
            flush()
        }

        private mutating func readMarkup() {
            let rest = html[index...]
            for (opening, closing) in [("<!--", "-->"), ("<![CDATA[", "]]>"), ("<!", ">"), ("<?", ">")] where rest.hasPrefix(opening) {
                index = rest.range(of: closing).map(\.upperBound) ?? html.endIndex
                return
            }
            guard let end = rest.firstIndex(of: ">") else {
                index = html.endIndex
                return
            }
            let tag = rest[rest.index(after: rest.startIndex) ..< end]
            index = html.index(after: end)
            let isClosing = tag.hasPrefix("/")
            let name = tag.drop { $0 == "/" }.prefix { $0.isLetter || $0.isNumber }.lowercased()
            guard !name.isEmpty else { return }
            handle(name, isClosing: isClosing, selfClosing: tag.hasSuffix("/"))
        }

        private mutating func handle(_ name: String, isClosing: Bool, selfClosing: Bool) {
            if let skipping {
                if isClosing, name == skipping {
                    self.skipping = nil
                }
                return
            }
            if HTMLTextExtractor.skipped.contains(name), !isClosing, !selfClosing {
                skipping = name
                return
            }
            if name == "pre" {
                if isClosing {
                    endPreformatted()
                } else {
                    beginPreformatted()
                }
                return
            }
            if name == "br" {
                if preformatted != nil {
                    preformatted? += "\n"
                } else {
                    text += "\n"
                }
                return
            }
            guard HTMLTextExtractor.blocks.contains(name) else { return }
            flush()
            if isClosing {
                if let open = stack.lastIndex(where: { $0.name == name }) {
                    stack.removeSubrange(open...)
                }
                // Items sit on consecutive lines; the list as a whole is a block.
                if name == "ul" || name == "ol", !segments.isEmpty {
                    segments[segments.count - 1].endsBlock = true
                }
            } else if !selfClosing, name != "hr" {
                var open = Open(name: name)
                if name == "li" {
                    open.marker = listMarker()
                }
                stack.append(open)
            }
        }

        /// `- ` in a `ul`, the item's number in an `ol`, indented by the lists around it.
        private mutating func listMarker() -> String {
            let depth = stack.count { $0.name == "ul" || $0.name == "ol" }
            let indent = String(repeating: "  ", count: max(0, depth - 1))
            guard let list = stack.lastIndex(where: { $0.name == "ul" || $0.name == "ol" }), stack[list].name == "ol" else {
                return indent + "- "
            }
            stack[list].count += 1
            return indent + "\(stack[list].count). "
        }

        private mutating func beginPreformatted() {
            flush()
            preformatted = ""
        }

        private mutating func endPreformatted() {
            guard let code = preformatted else { return }
            preformatted = nil
            let trimmed = code.trimmingCharacters(in: .newlines)
            guard !trimmed.isEmpty else { return }
            segments.append(DocumentSegment(id: nextID, text: "", verbatim: "```\n\(trimmed)\n```"))
            nextID += 1
        }

        /// Ends the current block: its text, whitespace collapsed, with the marker of the block it is in.
        private mutating func flush() {
            let lines = text.split(separator: "\n").map { $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") }
            text = ""
            let collapsed = lines.filter { !$0.isEmpty }.joined(separator: "\n")
            guard !collapsed.isEmpty else { return }
            let inList = stack.last { $0.name == "li" } != nil && !stack.contains { $0.name.first == "h" && $0.name.count == 2 }
            segments.append(DocumentSegment(id: nextID, text: collapsed, prefix: prefix(), endsBlock: !inList))
            nextID += 1
        }

        private func prefix() -> String {
            let quotes = String(repeating: "> ", count: stack.count { $0.name == "blockquote" })
            if let heading = stack.last(where: { $0.name.count == 2 && $0.name.first == "h" }), let level = Int(heading.name.dropFirst()) {
                return quotes + String(repeating: "#", count: level) + " "
            }
            if let item = stack.last(where: { $0.name == "li" }) {
                return quotes + item.marker
            }
            return quotes
        }
    }
}
