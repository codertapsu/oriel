import AppKit
@testable import ColorPicker
import Foundation
import Testing

struct PaletteExportTests {
    private func palette() -> Palette {
        Palette(name: "Brand Colors", colors: [
            PaletteColor(color: .hex("#FF8800"), name: "Orange"),
            PaletteColor(color: .hex("#33669980")),
            PaletteColor(color: ColorValue(displayP3: SIMD3(1, 0, 0)), name: "Vivid red"),
            PaletteColor(color: .hex("#000000"), name: "Orange"),
        ])
    }

    @Test func cssVariablesGiveWideColorsADisplayP3Value() {
        let css = PaletteExport.css(palette())
        #expect(css == """
        /* Brand Colors, exported from Oriel */
        :root {
          --brand-colors-orange: #FF8800;
          --brand-colors-2: #33669980;
          --brand-colors-vivid-red: #FF0000;
          --brand-colors-orange-2: #000000;
        }

        @supports (color: color(display-p3 1 1 1)) {
          :root {
            --brand-colors-vivid-red: color(display-p3 1 0 0);
          }
        }

        """)
    }

    @Test func jsonCarriesHexAndTheExactComponents() throws {
        let data = try PaletteExport.json(palette(), uppercaseHex: false)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["name"] as? String == "Brand Colors")
        let colors = try #require(object["colors"] as? [[String: Any]])
        #expect(colors.count == 4)
        #expect(colors[0]["name"] as? String == "Orange")
        #expect(colors[0]["hex"] as? String == "#ff8800")
        #expect(colors[1]["hex"] as? String == "#33669980")
        #expect(colors[1]["name"] == nil)
        #expect(colors[1]["alpha"] as? Double == 0.502)
        let wide = try #require(colors[2]["srgb"] as? [Double])
        #expect(approximately(wide[0], 1.0931, 1e-4) && wide[1] < 0)
        #expect(colors[2]["displayP3"] as? [Double] == [1, 0, 0])
    }

    @Test(arguments: [
        ("Brand Colors", "brand-colors"), ("  --Hello__World--  ", "hello-world"), ("Màu đỏ", "mau-do"),
        ("Ελληνικά", "ellenika"), ("🎨", nil), ("A/B 50%", "a-b-50"),
    ])
    func slugsAreSafeForCSS(_ name: String, _ expected: String?) {
        #expect(PaletteExport.slug(name) == expected)
    }

    @Test func aColorListRoundTripsThroughNSColorList() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "PaletteExportTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Brand.clr")
        let palette = palette()
        try ColorListWriter.write(palette, to: url)
        let list = try #require(NSColorList(name: "Brand", fromFile: url.path))
        #expect(list.allKeys == ["Orange", "#33669980", "Vivid red", "Orange 2"])
        let red = try #require(list.color(withKey: "Vivid red").flatMap(ColorValue.init))
        #expect(red.isSameColor(as: ColorValue(displayP3: SIMD3(1, 0, 0))))
        let translucent = try #require(list.color(withKey: "#33669980").flatMap(ColorValue.init))
        #expect(translucent.hex(includesAlpha: true) == "#33669980")
    }
}
