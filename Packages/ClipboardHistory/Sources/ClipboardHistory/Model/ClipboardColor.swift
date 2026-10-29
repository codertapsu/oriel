import Foundation

/// A color written as text, so a copied color shows as a swatch: `#F80`, `#FF8800`, `#FF880080`, `rgb(255, 136, 0)`,
/// `rgba(255 136 0 / 50%)`, `hsl(32, 100%, 50%)` or `hsla(…)`. Components are 0…1.
nonisolated struct ClipboardColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// Parses the whole of `text`, spaces around it aside; nil unless it is exactly one color.
    init?(parsing text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count <= 64 else { return nil }
        if trimmed.hasPrefix("#") {
            self.init(hex: trimmed.dropFirst())
        } else if let open = trimmed.firstIndex(of: "("), trimmed.hasSuffix(")") {
            let name = trimmed[..<open]
            let arguments = trimmed[trimmed.index(after: open) ..< trimmed.index(before: trimmed.endIndex)]
            self.init(function: String(name), arguments: String(arguments))
        } else {
            return nil
        }
    }

    /// "#RRGGBB", or "#RRGGBBAA" when not opaque.
    var hex: String {
        let channels = alpha < 1 ? [red, green, blue, alpha] : [red, green, blue]
        return "#" + channels.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
    }

    var rgbDescription: String {
        let values = [red, green, blue].map { String(Int(($0 * 255).rounded())) }.joined(separator: ", ")
        return alpha < 1 ? "rgba(\(values), \(Self.format(alpha)))" : "rgb(\(values))"
    }

    var hslDescription: String {
        let high = max(red, green, blue)
        let low = min(red, green, blue)
        let lightness = (high + low) / 2
        let delta = high - low
        var hue = 0.0
        var saturation = 0.0
        if delta > 0 {
            saturation = delta / (1 - abs(2 * lightness - 1))
            if high == red {
                hue = 60 * ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if high == green {
                hue = 60 * ((blue - red) / delta + 2)
            } else {
                hue = 60 * ((red - green) / delta + 4)
            }
        }
        let degrees = Int((hue < 0 ? hue + 360 : hue).rounded()) % 360
        let values = "\(degrees), \(Int((saturation * 100).rounded()))%, \(Int((lightness * 100).rounded()))%"
        return alpha < 1 ? "hsla(\(values), \(Self.format(alpha)))" : "hsl(\(values))"
    }

    // MARK: Parsing

    private init?(hex digits: Substring) {
        guard [3, 4, 6, 8].contains(digits.count), digits.allSatisfy(\.isHexDigit) else { return nil }
        let expanded = digits.count <= 4 ? String(digits.flatMap { [$0, $0] }) : String(digits)
        var values: [Double] = []
        var index = expanded.startIndex
        while index < expanded.endIndex {
            let next = expanded.index(index, offsetBy: 2)
            guard let byte = UInt8(expanded[index ..< next], radix: 16) else { return nil }
            values.append(Double(byte) / 255)
            index = next
        }
        self.init(red: values[0], green: values[1], blue: values[2], alpha: values.count == 4 ? values[3] : 1)
    }

    private init?(function name: String, arguments: String) {
        // "255, 136, 0, 0.5", "255 136 0 / 50%": commas, spaces and one slash before alpha all separate.
        let parts = arguments.replacingOccurrences(of: "/", with: " ").split { $0 == "," || $0.isWhitespace }.map(String.init)
        guard parts.count == 3 || parts.count == 4 else { return nil }
        let alpha = parts.count == 4 ? Self.unit(parts[3], scale: 1) : 1
        guard let alpha else { return nil }
        switch name {
        case "rgb", "rgba":
            guard let red = Self.unit(parts[0], scale: 255), let green = Self.unit(parts[1], scale: 255),
                  let blue = Self.unit(parts[2], scale: 255)
            else { return nil }
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        case "hsl", "hsla":
            guard let hue = Double(parts[0].replacingOccurrences(of: "deg", with: "")),
                  parts[1].hasSuffix("%"), parts[2].hasSuffix("%"),
                  let saturation = Self.unit(parts[1], scale: 1), let lightness = Self.unit(parts[2], scale: 1)
            else { return nil }
            let (red, green, blue) = Self.rgb(hue: hue, saturation: saturation, lightness: lightness)
            self.init(red: red, green: green, blue: blue, alpha: alpha)
        default:
            return nil
        }
    }

    /// A number out of `scale` or a percentage, as 0…1; nil when out of range.
    private static func unit(_ text: String, scale: Double) -> Double? {
        let value: Double? = if text.hasSuffix("%") {
            Double(text.dropLast()).map { $0 / 100 }
        } else {
            Double(text).map { $0 / scale }
        }
        guard let value, (0 ... 1).contains(value) else { return nil }
        return value
    }

    private static func rgb(hue: Double, saturation: Double, lightness: Double) -> (Double, Double, Double) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let sector = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let second = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let match = lightness - chroma / 2
        let (red, green, blue): (Double, Double, Double) = switch Int(sector) {
        case 0: (chroma, second, 0)
        case 1: (second, chroma, 0)
        case 2: (0, chroma, second)
        case 3: (0, second, chroma)
        case 4: (second, 0, chroma)
        default: (chroma, 0, second)
        }
        return (red + match, green + match, blue + match)
    }

    private static func format(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}
