/// Splits a byte stream into lines (LF or CRLF), keeping empty lines, which `AsyncLineSequence` would drop and SSE
/// needs as event boundaries. Lines are decoded as UTF-8 only once complete, so a character split across network
/// packets is never broken.
struct LineSplitter {
    private var line: [UInt8] = []

    /// Takes the next byte and returns a line when the byte ends one.
    mutating func push(_ byte: UInt8) -> String? {
        guard byte == UInt8(ascii: "\n") else {
            line.append(byte)
            return nil
        }
        if line.last == UInt8(ascii: "\r") {
            line.removeLast()
        }
        defer { line.removeAll(keepingCapacity: true) }
        return UTF8Text.decode(line)
    }

    /// The last line, when the stream did not end with a line break.
    mutating func finish() -> String? {
        guard !line.isEmpty else { return nil }
        defer { line.removeAll() }
        return UTF8Text.decode(line)
    }
}
