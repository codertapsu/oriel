import AppKit

/// Writes a palette as an Apple color list (`.clr`, `NSColorList.write(to:)`), which the system Colors panel and design
/// apps open. A color list names every color, and the names must differ, so an unnamed color is named by its HEX and
/// a repeated name gets a number.
nonisolated enum ColorListWriter {
    static func write(_ palette: Palette, to url: URL, uppercaseHex: Bool = true) throws {
        let list = NSColorList(name: palette.name)
        for (index, key) in keys(for: palette, uppercaseHex: uppercaseHex).enumerated() {
            list.insertColor(palette.colors[index].color.nsColor, key: key, at: index)
        }
        try list.write(to: url)
    }

    /// One unique key per color, in order.
    static func keys(for palette: Palette, uppercaseHex: Bool = true) -> [String] {
        var used: Set<String> = []
        return palette.colors.map { entry in
            let base = entry.name ?? entry.color.hex(uppercase: uppercaseHex, includesAlpha: !entry.color.isOpaque)
            var key = base
            var number = 2
            while !used.insert(key).inserted {
                key = "\(base) \(number)"
                number += 1
            }
            return key
        }
    }
}
