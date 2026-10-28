/// Server-sent events, line by line (the WHATWG event-stream format that OpenAI-compatible servers and Anthropic
/// use). `data:` lines accumulate until a blank line dispatches the event; comments and unknown fields are ignored.
struct SSEParser {
    struct Event: Equatable, Sendable {
        /// The `event:` field, if the server sent one (Anthropic does, OpenAI does not).
        var name: String?
        var data: String
    }

    private var name: String?
    private var dataLines: [String] = []

    /// Takes one line without its line break. Returns an event when the line completes one.
    mutating func feed(line: String) -> Event? {
        if line.isEmpty {
            return dispatch()
        }
        if line.hasPrefix(":") {
            return nil
        }
        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.hasPrefix(" ") {
                value = value.dropFirst()
            }
        } else {
            field = Substring(line)
            value = ""
        }
        switch field {
        case "event":
            // A server that skips the blank line before the next event still gets its previous event dispatched.
            let pending = dispatch()
            name = String(value)
            return pending
        case "data":
            dataLines.append(String(value))
        default:
            break
        }
        return nil
    }

    /// Dispatches a last event that the stream did not end with a blank line.
    mutating func finish() -> Event? {
        dispatch()
    }

    private mutating func dispatch() -> Event? {
        defer {
            name = nil
            dataLines = []
        }
        guard !dataLines.isEmpty else { return nil }
        return Event(name: name, data: dataLines.joined(separator: "\n"))
    }
}
