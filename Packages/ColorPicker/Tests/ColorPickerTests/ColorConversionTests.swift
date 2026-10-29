import AppKit
@testable import ColorPicker
import Testing

/// Reference values: CSS Color 4 (its sample conversion code and examples) for OKLCH and Display P3, and the textbook
/// HSL, HSB and CMYK of well-known colors.
struct ColorConversionTests {
    @Test func hslHSBAndCMYKOfKnownColors() {
        let orange = ColorValue.hex("#FF8800")
        let hsl = HSLColor(orange)
        #expect(approximately(hsl.hue, 32, 1e-9) && hsl.saturation == 1 && hsl.lightness == 0.5)
        let hsb = HSBColor(orange)
        #expect(approximately(hsb.hue, 32, 1e-9) && hsb.saturation == 1 && hsb.brightness == 1)
        let cmyk = CMYKColor(orange)
        #expect(cmyk.cyan == 0 && approximately(cmyk.magenta, 1 - 136.0 / 255) && cmyk.yellow == 1 && cmyk.key == 0)

        let blue = ColorValue.hex("#336699")
        let blueHSL = HSLColor(blue)
        #expect(approximately(blueHSL.hue, 210) && approximately(blueHSL.saturation, 0.5) && approximately(blueHSL.lightness, 0.4))
        let blueHSB = HSBColor(blue)
        #expect(approximately(blueHSB.hue, 210) && approximately(blueHSB.saturation, 2.0 / 3) && approximately(blueHSB.brightness, 0.6))
        let blueCMYK = CMYKColor(blue)
        #expect(approximately(blueCMYK.cyan, 2.0 / 3) && approximately(blueCMYK.magenta, 1.0 / 3))
        #expect(approximately(blueCMYK.yellow, 0) && approximately(blueCMYK.key, 0.4))
    }

    @Test func graysHaveNoHueAndBlackIsAllKey() {
        let gray = HSLColor(.hex("#808080"))
        #expect(gray.hue == 0 && gray.saturation == 0)
        let black = CMYKColor(.black)
        #expect(black.key == 1 && black.cyan == 0 && black.magenta == 0 && black.yellow == 0)
        #expect(HSBColor(.black).saturation == 0)
    }

    @Test(arguments: ["#FF8800", "#336699", "#000000", "#FFFFFF", "#7F7F7F", "#12AB34", "#FF00FF", "#C0FFEE", "#FA0001"])
    func hslAndHSBRoundTrip(_ hex: String) {
        let color = ColorValue.hex(hex)
        #expect(HSLColor(color).color.hex() == hex)
        #expect(HSBColor(color).color.hex() == hex)
        #expect(approximately(HSLColor(color).color.components, color.components, 1e-9))
    }

    /// CSS Color 4's OKLCH of the sRGB primaries and white.
    @Test(arguments: [
        ("#FF0000", 0.627_955, 0.257_683, 29.2339),
        ("#00FF00", 0.866_440, 0.294_827, 142.4953),
        ("#0000FF", 0.452_014, 0.313_214, 264.0520),
        ("#FFFFFF", 1.0, 0.0, 0.0),
        ("#000000", 0.0, 0.0, 0.0),
    ])
    func oklchOfReferenceColors(_ hex: String, _ lightness: Double, _ chroma: Double, _ hue: Double) {
        let lch = OKLCHColor(.hex(hex))
        #expect(approximately(lch.lightness, lightness, 1e-5))
        #expect(approximately(lch.chroma, chroma, 1e-5))
        #expect(approximately(lch.hue, hue, 1e-3))
    }

    /// Ottosson's matrices are published to ten digits, so the round trip is exact to about 1e-6, thousands of times
    /// finer than an 8-bit step.
    @Test(arguments: ["#FF8800", "#336699", "#123456", "#FEDCBA", "#00FF00", "#808080"])
    func oklchRoundTrips(_ hex: String) {
        let color = ColorValue.hex(hex)
        #expect(approximately(OKLCHColor(color).color.components, color.components, 1e-5))
    }

    /// Display P3 red is outside sRGB: about rgb(109.3% −22.7% −15.0%) in extended sRGB, and sRGB red is
    /// color(display-p3 0.9175 0.2003 0.1386).
    @Test func displayP3ToSRGBAndBack() {
        let p3Red = ColorValue(displayP3: SIMD3(1, 0, 0))
        #expect(approximately(p3Red.components, SIMD3(1.093_066, -0.226_742, -0.150_135), 1e-5))
        #expect(!p3Red.isInSRGBGamut)
        #expect(p3Red.hex() == "#FF0000")
        #expect(approximately(ColorValue.hex("#FF0000").displayP3, SIMD3(0.917_488, 0.200_287, 0.138_561), 1e-5))
        #expect(approximately(p3Red.displayP3, SIMD3(1, 0, 0), 1e-9))
        let p3Green = ColorValue(displayP3: SIMD3(0, 1, 0))
        #expect(approximately(p3Green.components, SIMD3(-0.511_605, 1.018_266, -0.310_675), 1e-5))
    }

    /// The math agrees with ColorSync, which is what macOS uses when NSColorSampler hands over a P3 color.
    @Test func displayP3MathMatchesAppKit() throws {
        for (red, green, blue) in [(1.0, 0.0, 0.0), (0.2, 0.8, 0.3), (0.95, 0.6, 0.1), (0.5, 0.5, 0.5)] {
            let appKit = try #require(ColorValue(NSColor(displayP3Red: red, green: green, blue: blue, alpha: 1)))
            let math = ColorValue(displayP3: SIMD3(red, green, blue))
            #expect(approximately(appKit.components, math.components, 0.002), "P3 \(red), \(green), \(blue)")
        }
    }

    @Test func gamutAllowsHalfAnEightBitStep() {
        #expect(ColorValue(red: 1.001, green: 0.5, blue: -0.001).isInSRGBGamut)
        #expect(!ColorValue(red: 1.01, green: 0.5, blue: 0).isInSRGBGamut)
        #expect(!ColorValue(red: 0.5, green: -0.01, blue: 0).isInSRGBGamut)
    }

    @Test func hexRoundsAndClipsAndKeepsAlpha() throws {
        let color = ColorValue(red: 1.2, green: 0.5, blue: -0.1, alpha: 0.5)
        #expect(color.hex() == "#FF8000")
        #expect(color.hex(uppercase: false, includesAlpha: true) == "#ff800080")
        #expect(try #require(ColorValue(hex: "#F80")).hex() == "#FF8800")
        #expect(try #require(ColorValue(hex: "f808")).hex(includesAlpha: true) == "#FF880088")
        #expect(try #require(ColorValue(hex: " #ff8800 ")).bytes == ColorValue.Bytes(red: 255, green: 136, blue: 0, alpha: 255))
        for bad in ["#12", "#GGGGGG", "FF88001", "", "#"] {
            #expect(ColorValue(hex: bad) == nil, "\(bad)")
        }
    }

    @Test func aColorPickedTwiceIsTheSameColor() {
        let first = ColorValue.hex("#FF8800")
        let second = ColorValue(red: 0.999_9, green: 136.0 / 255 + 0.000_8, blue: 0.000_5)
        #expect(first.isSameColor(as: second))
        #expect(!first.isSameColor(as: .hex("#FF8801")))
        #expect(!first.isSameColor(as: .hex("#FF8800FE")))
    }

    @Test func legibleTextIsBlackOnLightAndWhiteOnDark() {
        #expect(ColorValue.hex("#FFDD00").legibleTextColor == .black)
        #expect(ColorValue.hex("#1A237E").legibleTextColor == .white)
    }
}
