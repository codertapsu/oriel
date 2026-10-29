@testable import ClipboardHistory
import Testing

struct ClipboardColorTests {
    @Test(arguments: [
        ("#F80", "#FF8800"),
        ("#ff8800", "#FF8800"),
        ("#FF880080", "#FF880080"),
        ("#F808", "#FF880088"),
        ("rgb(255, 136, 0)", "#FF8800"),
        ("rgba(255,136,0,0.5)", "#FF880080"),
        ("rgb(255 136 0 / 50%)", "#FF880080"),
        ("rgb(100%, 0%, 0%)", "#FF0000"),
        ("hsl(0, 100%, 50%)", "#FF0000"),
        ("hsl(120deg 100% 25%)", "#008000"),
        ("hsla(240, 100%, 50%, 0.5)", "#0000FF80"),
        ("  #000000 \n", "#000000"),
    ])
    func parsesCommonNotations(_ text: String, _ hex: String) throws {
        #expect(try #require(ClipboardColor(parsing: text)).hex == hex)
    }

    @Test(arguments: ["#12", "#GGGGGG", "rgb(300, 0, 0)", "rgb(1, 2)", "hsl(0, 50, 50)", "red", "#FF8800 and more", "rgb(1,2,3,4,5)"])
    func rejectsWhatIsNotOneColor(_ text: String) {
        #expect(ClipboardColor(parsing: text) == nil)
    }

    @Test func describesTheColorInEveryNotation() throws {
        let color = try #require(ClipboardColor(parsing: "#FF8800"))
        #expect(color.rgbDescription == "rgb(255, 136, 0)")
        #expect(color.hslDescription == "hsl(32, 100%, 50%)")
        let translucent = try #require(ClipboardColor(parsing: "rgba(0, 0, 255, 0.25)"))
        #expect(translucent.rgbDescription == "rgba(0, 0, 255, 0.25)")
        #expect(translucent.hslDescription == "hsla(240, 100%, 50%, 0.25)")
    }
}
