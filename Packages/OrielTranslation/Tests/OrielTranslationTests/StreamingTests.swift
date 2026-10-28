@testable import OrielTranslation
import Testing

/// Server-sent events and the line splitting under them.
struct StreamingTests {
    private func events(_ lines: [String]) -> [SSEParser.Event] {
        var parser = SSEParser()
        var events = lines.compactMap { parser.feed(line: $0) }
        if let last = parser.finish() {
            events.append(last)
        }
        return events
    }

    @Test func dispatchesDataOnlyEventsAtBlankLines() {
        let result = events(["data: {\"a\":1}", "", "data: [DONE]", ""])
        #expect(result == [SSEParser.Event(name: nil, data: "{\"a\":1}"), SSEParser.Event(name: nil, data: "[DONE]")])
    }

    @Test func keepsEventNamesAndJoinsMultiLineData() {
        let result = events([": keep-alive", "event: content_block_delta", "data: first", "data:second", "id: 7", "", "retry: 10"])
        #expect(result == [SSEParser.Event(name: "content_block_delta", data: "first\nsecond")])
    }

    @Test func dispatchesWhenANewEventStartsWithoutABlankLineAndAtTheEnd() {
        let result = events(["event: one", "data: 1", "event: two", "data: 2"])
        #expect(result == [SSEParser.Event(name: "one", data: "1"), SSEParser.Event(name: "two", data: "2")])
    }

    @Test func splitsLinesOnLFAndCRLFAndKeepsEmptyLines() {
        var splitter = LineSplitter()
        var lines: [String] = []
        for byte in Array("data: a\r\n\r\ndata: b\n\nlast".utf8) {
            if let line = splitter.push(byte) {
                lines.append(line)
            }
        }
        if let line = splitter.finish() {
            lines.append(line)
        }
        #expect(lines == ["data: a", "", "data: b", "", "last"])
    }

    @Test func decodesMultiByteCharactersOnlyOnceTheLineIsComplete() {
        var splitter = LineSplitter()
        var lines: [String] = []
        for byte in Array("こんにちは 😀\n".utf8) {
            if let line = splitter.push(byte) {
                lines.append(line)
            }
        }
        #expect(lines == ["こんにちは 😀"])
        #expect(UTF8Text.decode([0x61, 0xE3, 0x81]) == "a\u{FFFD}")
    }
}
