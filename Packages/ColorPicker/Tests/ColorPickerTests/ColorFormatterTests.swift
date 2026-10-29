@testable import ColorPicker
import Testing

struct ColorFormatterTests {
    @Test(arguments: [
        (ColorFormat.hex, "#FF8800"),
        (.hexAlpha, "#FF8800FF"),
        (.rgb, "rgb(255, 136, 0)"),
        (.rgba, "rgba(255, 136, 0, 1)"),
        (.hsl, "hsl(32, 100%, 50%)"),
        (.hsb, "hsb(32, 100%, 100%)"),
        (.oklch, "oklch(0.744 0.181 56.5)"),
        (.swiftUI, "Color(red: 1, green: 0.533, blue: 0)"),
        (.nsColor, "NSColor(srgbRed: 1, green: 0.533, blue: 0, alpha: 1)"),
        (.uiColor, "UIColor(red: 1, green: 0.533, blue: 0, alpha: 1)"),
        (.rgbPercent, "rgb(100%, 53.3%, 0%)"),
        (.cmyk, "cmyk(0%, 47%, 100%, 0%)"),
        (.displayP3, "color(display-p3 0.939 0.558 0.206)"),
    ])
    func everyFormatOfAnOpaqueColor(_ format: ColorFormat, _ expected: String) {
        #expect(ColorFormatter.string(format, for: .hex("#FF8800")) == expected)
    }

    @Test(arguments: [
        (ColorFormat.hex, "#ff8800"),
        (.hexAlpha, "#ff880080"),
        (.rgb, "rgb(255, 136, 0)"),
        (.rgba, "rgba(255, 136, 0, 0.502)"),
        (.hsl, "hsla(32, 100%, 50%, 0.502)"),
        (.hsb, "hsba(32, 100%, 100%, 0.502)"),
        (.oklch, "oklch(0.744 0.181 56.5 / 0.502)"),
        (.swiftUI, "Color(red: 1, green: 0.533, blue: 0, opacity: 0.502)"),
        (.nsColor, "NSColor(srgbRed: 1, green: 0.533, blue: 0, alpha: 0.502)"),
        (.rgbPercent, "rgba(100%, 53.3%, 0%, 0.502)"),
        (.displayP3, "color(display-p3 0.939 0.558 0.206 / 0.502)"),
    ])
    func alphaIsKeptAndHexCanBeLowercase(_ format: ColorFormat, _ expected: String) {
        #expect(ColorFormatter.string(format, for: .hex("#FF880080"), uppercaseHex: false) == expected)
    }

    /// Outside sRGB the CSS formats clip, and the code formats switch to their Display P3 initializers so they draw
    /// the color that was picked.
    @Test func aColorOutsideSRGBIsWrittenInDisplayP3WhereTheFormatCan() {
        let p3Red = ColorValue(displayP3: SIMD3(1, 0, 0))
        #expect(ColorFormatter.string(.hex, for: p3Red) == "#FF0000")
        #expect(ColorFormatter.string(.displayP3, for: p3Red) == "color(display-p3 1 0 0)")
        #expect(ColorFormatter.string(.swiftUI, for: p3Red) == "Color(.displayP3, red: 1, green: 0, blue: 0)")
        #expect(ColorFormatter.string(.nsColor, for: p3Red) == "NSColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)")
        #expect(ColorFormatter.string(.uiColor, for: p3Red) == "UIColor(displayP3Red: 1, green: 0, blue: 0, alpha: 1)")
        #expect(ColorFormatter.title(.swiftUI, for: p3Red) == "SwiftUI · P3")
        #expect(ColorFormatter.title(.swiftUI, for: .hex("#FF0000")) == "SwiftUI")
        // OKLCH keeps the wider chroma that sRGB red does not have.
        #expect(OKLCHColor(p3Red).chroma > OKLCHColor(.hex("#FF0000")).chroma + 0.03)
    }

    @Test(arguments: [
        (0.5, 3, "0.5"), (1.0, 3, "1"), (0.0, 3, "0"), (-0.2267, 3, "-0.227"), (-0.000_1, 3, "0"),
        (12.3456, 1, "12.3"), (99.96, 1, "100"), (0.053_33, 3, "0.053"), (264.052, 1, "264.1"), (7.0, 0, "7"),
    ])
    func decimalsUseAFullStopAndNoTrailingZeros(_ value: Double, _ places: Int, _ expected: String) {
        #expect(ColorFormatter.decimal(value, places: places) == expected)
    }

    @Test func hueRoundsUpToZeroNotThreeSixty() {
        let almostRed = HSLColor(hue: 359.7, saturation: 1, lightness: 0.5).color
        #expect(ColorFormatter.string(.hsl, for: almostRed).hasPrefix("hsl(0, "))
    }

    @Test func theFirstTenFormatsHaveNumberKeys() {
        #expect(ColorFormat.hex.keyNumber == 1)
        #expect(ColorFormat.nsColor.keyNumber == 9)
        #expect(ColorFormat.uiColor.keyNumber == 0)
        #expect(ColorFormat.rgbPercent.keyNumber == nil)
        #expect(ColorFormat.format(forKeyNumber: 0) == .uiColor)
        #expect(ColorFormat.format(forKeyNumber: 2) == .hexAlpha)
        #expect(ColorFormat.allCases.compactMap(\.keyNumber) == [1, 2, 3, 4, 5, 6, 7, 8, 9, 0])
    }

    @Test func displayP3IsShownOnlyWhenItDiffersFromSRGB() {
        #expect(!ColorFormat.displayP3.isShown(for: .hex("#808080")))
        #expect(!ColorFormat.displayP3.isShown(for: .white))
        #expect(ColorFormat.displayP3.isShown(for: .hex("#FF8800")))
        #expect(ColorFormat.hex.isShown(for: .hex("#808080")))
    }
}
