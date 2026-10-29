/// One 8-bit RGBA pixel as `PixelImage` stores it (premultiplied; screenshots are opaque, so mostly plain RGB).
nonisolated struct PixelColor: Sendable, Hashable {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var alpha: UInt8

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// The largest difference in any colour channel, 0…255: how far apart two colours look, cheaply.
    func distance(to other: PixelColor) -> Int {
        max(abs(Int(red) - Int(other.red)), abs(Int(green) - Int(other.green)), abs(Int(blue) - Int(other.blue)))
    }

    /// Perceived brightness, 0…255 (Rec. 709 weights).
    var luminance: Double {
        0.2126 * Double(red) + 0.7152 * Double(green) + 0.0722 * Double(blue)
    }

    /// The colour as the document stores colours.
    var rgbaColor: RGBAColor {
        let alpha = Double(alpha) / 255
        guard alpha > 0 else { return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0) }
        // Undo the premultiplication.
        return RGBAColor(
            red: min(1, Double(red) / 255 / alpha),
            green: min(1, Double(green) / 255 / alpha),
            blue: min(1, Double(blue) / 255 / alpha),
            alpha: alpha
        )
    }

    /// The colour with its channels rounded to `step`, so near-identical shades count as one.
    func quantized(step: UInt8 = 8) -> PixelColor {
        func round(_ value: UInt8) -> UInt8 {
            UInt8(min(255, (Int(value) + Int(step) / 2) / Int(step) * Int(step)))
        }
        return PixelColor(red: round(red), green: round(green), blue: round(blue), alpha: round(alpha))
    }
}
