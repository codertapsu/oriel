import Foundation

/// A palette written for other tools: JSON and CSS custom properties here, the `.clr` color list in
/// `ColorListWriter` (it needs AppKit). Each color gets a stable name: its own, made safe for CSS, or its position.
nonisolated enum PaletteExport {
    /// ```json
    /// { "name": "Brand",
    ///   "colors": [{ "name": "Orange", "hex": "#FF8800", "srgb": [1, 0.5333, 0], "alpha": 1,
    ///                "displayP3": [0.9387, 0.5575, 0.2057] }] }
    /// ```
    /// `hex` is clipped to sRGB (with alpha when not opaque); `srgb` keeps the exact, possibly extended, components.
    static func json(_ palette: Palette, uppercaseHex: Bool = true) throws -> Data {
        let colors = palette.colors.map { entry in
            let color = entry.color
            let p3 = color.displayP3
            return ExportedColor(
                name: entry.name,
                hex: color.hex(uppercase: uppercaseHex, includesAlpha: !color.isOpaque),
                srgb: [color.red, color.green, color.blue].map(rounded),
                alpha: rounded(color.alpha),
                displayP3: [p3.x, p3.y, p3.z].map(rounded)
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(ExportedPalette(name: palette.name, colors: colors))
    }

    /// `:root { --brand-orange: #FF8800; }`, and an `@supports` block that gives the colors sRGB cannot show their
    /// Display P3 value where the browser understands it.
    static func css(_ palette: Palette, uppercaseHex: Bool = true) -> String {
        let names = variableNames(for: palette)
        let entries = Array(zip(names, palette.colors))
        var lines = ["/* \(palette.name.replacingOccurrences(of: "*/", with: "* /")), exported from Oriel */", ":root {"]
        for (name, entry) in entries {
            let format: ColorFormat = entry.color.isOpaque ? .hex : .hexAlpha
            lines.append("  --\(name): \(ColorFormatter.string(format, for: entry.color, uppercaseHex: uppercaseHex));")
        }
        lines.append("}")
        let wide = entries.filter { !$0.1.color.isInSRGBGamut }
        if !wide.isEmpty {
            lines += ["", "@supports (color: color(display-p3 1 1 1)) {", "  :root {"]
            for (name, entry) in wide {
                lines.append("    --\(name): \(ColorFormatter.string(.displayP3, for: entry.color));")
            }
            lines += ["  }", "}"]
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// One CSS-safe, unique name per color: `brand-orange` for a color named Orange in Brand, `brand-2` for the second
    /// color when it has no name.
    static func variableNames(for palette: Palette) -> [String] {
        let prefix = slug(palette.name) ?? "palette"
        var used: Set<String> = []
        return palette.colors.enumerated().map { index, entry in
            let base = "\(prefix)-\(entry.name.flatMap(slug) ?? String(index + 1))"
            var name = base
            var suffix = 2
            while !used.insert(name).inserted {
                name = "\(base)-\(suffix)"
                suffix += 1
            }
            return name
        }
    }

    /// Lowercase ASCII letters, digits and single hyphens, transliterated from any script ("Màu đỏ" → "mau-do"); nil
    /// when nothing is left.
    static func slug(_ text: String) -> String? {
        let latin = text.applyingTransform(StringTransform("Any-Latin; Latin-ASCII; Lower"), reverse: false) ?? text.lowercased()
        var result = ""
        for scalar in latin.unicodeScalars {
            if ("a" ... "z").contains(scalar) || ("0" ... "9").contains(scalar) {
                result.unicodeScalars.append(scalar)
            } else if !result.isEmpty, result.last != "-" {
                result.append("-")
            }
        }
        while result.last == "-" {
            result.removeLast()
        }
        return result.isEmpty ? nil : result
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 10000).rounded() / 10000
    }

    private struct ExportedPalette: Encodable {
        let name: String
        let colors: [ExportedColor]
    }

    private struct ExportedColor: Encodable {
        let name: String?
        let hex: String
        let srgb: [Double]
        let alpha: Double
        let displayP3: [Double]
    }
}
