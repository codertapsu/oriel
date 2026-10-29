import Foundation
@testable import OrielTranslation
import Testing

/// Parsing and writing SRT and WebVTT, keeping cue timing to the millisecond.
struct SubtitleFileTests {
    private let srt = "\u{FEFF}1\r\n00:00:01,000 --> 00:00:04,250\r\n<i>Hello there.</i>\r\nSecond line\r\n\r\n\r\n"
        + "7\r\n00:01:02,5 --> 00:01:04,000 X1:100 X2:200\r\n{\\an8}On top &amp; loud\r\n\r\n"
        + "garbage without timing\r\n\r\n3\r\n00:02:00,000 --> 00:02:01,000\r\n- Who?\r\n- Me.\r\n"

    private let vtt = """
    WEBVTT - Example

    STYLE
    ::cue { color: yellow }

    NOTE This is a comment

    intro
    00:01.000 --> 00:04.000 align:start position:10%
    <v Alice>Hi, <b>Bob</b>!</v>

    00:00:05.500 --> 00:00:07.000
    <c.loud>Fish &lt;&gt; chips</c>
    <00:00:06.000>later<ruby>漢字<rt>かんじ</rt></ruby>

    NOTE trailing comment

    """

    @Test func readsSRT() {
        let parsed = SubtitleFile.parse(srt)
        #expect(parsed.header == nil)
        #expect(parsed.cues.map(\.start) == [1000, 62500, 120_000])
        #expect(parsed.cues.map(\.end) == [4250, 64000, 121_000])
        #expect(parsed.cues.map(\.plainText) == ["Hello there.\nSecond line", "On top & loud", "- Who?\n- Me."])
        #expect(parsed.cues[1].leadingTag == #"{\an8}"#)
        #expect(parsed.cues.allSatisfy { $0.identifier == nil })
    }

    @Test func readsWebVTT() {
        let parsed = SubtitleFile.parse(vtt)
        #expect(parsed.header == "WEBVTT - Example\n\nSTYLE\n::cue { color: yellow }\n\nNOTE This is a comment")
        #expect(parsed.cues.count == 2)
        #expect(parsed.cues[0].identifier == "intro" && parsed.cues[0].settings == "align:start position:10%")
        #expect(parsed.cues[0].start == 1000 && parsed.cues[0].end == 4000)
        #expect(parsed.cues[0].plainText == "Hi, Bob!" && parsed.cues[0].leadingTag == "<v Alice>")
        #expect(parsed.cues[1].start == 5500 && parsed.cues[1].plainText == "Fish <> chips\nlater漢字")
    }

    @Test(arguments: [
        ("00:00:01,000", 1000), ("00:00:01.000", 1000), ("01:02.5", 62500), ("1:02:03,045", 3_723_045), ("00:00:07", 7000),
    ])
    func readsTimestamps(_ text: String, _ milliseconds: Int) {
        #expect(SubtitleFile.milliseconds(text) == milliseconds)
    }

    @Test(arguments: ["", "abc", "00:61:00,000", "00:00:-1,000", "1:2:3:4"])
    func refusesBrokenTimestamps(_ text: String) {
        #expect(SubtitleFile.milliseconds(text) == nil)
    }

    @Test func writesSRTWithTheOriginalTimingAndPositions() {
        let cues = SubtitleFile.parse(srt).cues
        let written = SubtitleFile.srt(cues.map { (cue: $0, text: "fr: \($0.plainText)") })
        #expect(written == """
        1
        00:00:01,000 --> 00:00:04,250
        fr: Hello there.
        Second line

        2
        00:01:02,500 --> 00:01:04,000
        {\\an8}fr: On top & loud

        3
        00:02:00,000 --> 00:02:01,000
        fr: - Who?
        - Me.


        """)
    }

    @Test func writesWebVTTWithItsHeaderIdentifiersSettingsAndVoices() {
        let parsed = SubtitleFile.parse(vtt)
        let written = SubtitleFile.vtt(parsed.cues.map { (cue: $0, text: "<\($0.plainText)> & co") }, header: parsed.header)
        #expect(written.hasPrefix("WEBVTT - Example\n\nSTYLE\n::cue { color: yellow }\n\nNOTE This is a comment\n\n"))
        #expect(written.contains("intro\n00:00:01.000 --> 00:00:04.000 align:start position:10%\n<v Alice>&lt;Hi, Bob!&gt; &amp; co\n\n"))
        #expect(written.contains("00:00:05.500 --> 00:00:07.000\n&lt;Fish <> chips".replacingOccurrences(of: "<>", with: "&lt;&gt;")))
        // Written WebVTT reads back with the same timing.
        let again = SubtitleFile.parse(written)
        #expect(again.cues.map(\.start) == parsed.cues.map(\.start) && again.cues.map(\.end) == parsed.cues.map(\.end))
    }

    @Test func srtBecomesWebVTT() {
        let cues = SubtitleFile.parse(srt).cues
        let written = SubtitleFile.vtt(cues.map { (cue: $0, text: $0.plainText) }, header: nil)
        #expect(written.hasPrefix("WEBVTT\n\n00:00:01.000 --> 00:00:04.250\nHello there.\nSecond line\n\n"))
        #expect(!written.contains(#"{\an8}"#))
    }
}
