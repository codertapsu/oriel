@testable import ColorPicker
import Testing

struct ColorParserTests {
    @Test(arguments: [
        ("#F80", "#FF8800FF"),
        ("ff8800", "#FF8800FF"),
        ("#FF880080", "#FF880080"),
        ("rgb(255, 136, 0)", "#FF8800FF"),
        ("rgba(255,136,0,0.5)", "#FF880080"),
        ("rgb(255 136 0 / 50%)", "#FF880080"),
        ("rgb(100%, 53.3%, 0%)", "#FF8800FF"),
        ("hsl(32, 100%, 50%)", "#FF8800FF"),
        ("hsl(32deg 100% 50%)", "#FF8800FF"),
        ("hsla(240, 100%, 50%, 0.25)", "#0000FF40"),
        ("hsb(210, 66.67%, 60%)", "#336699FF"),
        ("cmyk(0%, 47%, 100%, 0%)", "#FF8700FF"),
        ("cmyk(66.67%, 33.33%, 0%, 40%) ", "#336699FF"),
        ("oklch(0.628 0.258 29.23)", "#FF0000FF"),
        ("oklch(62.8% 0.258 29.23 / 0.5)", "#FF000080"),
        ("color(srgb 1 0.5333 0)", "#FF8800FF"),
        ("Color(red: 1, green: 0.533, blue: 0)", "#FF8800FF"),
        ("NSColor(srgbRed: 1, green: 0.533, blue: 0, alpha: 0.5)", "#FF880080"),
        ("UIColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)", "#336699FF"),
        ("  RGB(255, 136, 0)  ", "#FF8800FF"),
    ])
    func readsCommonNotations(_ text: String, _ expected: String) throws {
        #expect(try #require(ColorParser.parse(text)).hex(includesAlpha: true) == expected)
    }

    @Test func displayP3InputKeepsItsWideGamut() throws {
        let fromCSS = try #require(ColorParser.parse("color(display-p3 1 0 0)"))
        #expect(!fromCSS.isInSRGBGamut)
        #expect(approximately(fromCSS.displayP3, SIMD3(1, 0, 0), 1e-9))
        let fromCode = try #require(ColorParser.parse("NSColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)"))
        #expect(fromCode.isSameColor(as: fromCSS))
        let fromSwiftUI = try #require(ColorParser.parse("Color(.displayP3, red: 1, green: 0, blue: 0)"))
        #expect(fromSwiftUI.isSameColor(as: fromCSS))
    }

    @Test(arguments: [
        "", "red", "#12", "rgb(300, 0, 0)", "rgb(1, 2)", "rgb(1, 2, 3, 4, 5)", "rgba(1, 2, 3, 2)", "hsl(0, 150%, 50%)",
        "oklch(0.5 -0.1 20)", "color(rec2020 1 0 0)", "rgb(1 2 3 / )", "Color(red: 1, green: 0.5)", "#FF8800 and more",
    ])
    func rejectsWhatIsNotOneColor(_ text: String) {
        #expect(ColorParser.parse(text) == nil)
    }

    /// Typed nonsense never becomes infinities that would trap when a format turns them into whole numbers.
    @Test func absurdNumbersAreRefusedOrTamed() {
        for text in [
            "color(display-p3 1e300 0 0)", "color(srgb 1e999 0 0)", "Color(red: inf, green: 0, blue: 0)",
            "NSColor(srgbRed: 1e400, green: 0, blue: 0, alpha: 1)", "rgb(nan, 0, 0)", "oklch(0.5 5 20)",
            "hsl(infdeg, 50%, 50%)", "oklch(0.5 0.1 nan)",
        ] {
            #expect(ColorParser.parse(text) == nil, "\(text)")
        }
        let wild = ColorValue(red: .infinity, green: .nan, blue: 1e300, alpha: .nan)
        #expect(wild.red == 0 && wild.green == 0 && wild.blue == ColorValue.componentLimit && wild.alpha == 1)
        for format in ColorFormat.allCases {
            #expect(!ColorFormatter.string(format, for: wild).isEmpty)
        }
        #expect(ColorFormatter.decimal(.infinity, places: 3) == "0")
        #expect(ColorFormatter.decimal(1e300, places: 3) == "1000000000")
        #expect(WCAGContrast.ratioText(.nan) == "—")
        #expect(APCAContrast.text(APCAContrast.lightnessContrast(text: wild, background: .white)).hasPrefix("Lc "))
    }

    /// Whatever the panel copies, it reads back: the same 8-bit color for the sRGB formats, the exact color for the
    /// ones that carry more.
    @Test(arguments: ColorFormat.allCases)
    func everyCopiedFormatReadsBack(_ format: ColorFormat) throws {
        for color in [ColorValue.hex("#FF8800"), .hex("#336699CC"), .hex("#0A0B0C"), ColorValue(displayP3: SIMD3(0.1, 0.9, 0.2))] {
            let text = ColorFormatter.string(format, for: color)
            let parsed = try #require(ColorParser.parse(text), "\(text)")
            switch format {
            case .hex, .rgb, .hsl, .hsb, .cmyk:
                // These carry no more than 8 bits, and HSL, HSB and CMYK round to whole numbers.
                let tolerance = format == .hex || format == .rgb ? 0 : 3
                let expected = color.clamped.bytes
                let got = parsed.bytes
                #expect(abs(got.red - expected.red) <= tolerance && abs(got.green - expected.green) <= tolerance, "\(text)")
                #expect(abs(got.blue - expected.blue) <= tolerance, "\(text)")
            case .hexAlpha, .rgba, .rgbPercent:
                #expect(parsed.hex(includesAlpha: true) == color.hex(includesAlpha: true), "\(text)")
            case .oklch, .displayP3, .swiftUI, .nsColor, .uiColor:
                #expect(approximately(parsed.components, color.components, 0.004), "\(text)")
                #expect(approximately(parsed.alpha, color.alpha, 0.002), "\(text)")
            }
        }
    }
}
