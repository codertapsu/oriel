@testable import ScreenRuler

/// Pictures drawn in code for the edge tests: a background, then rectangles over it.
struct SyntheticBitmap {
    let width: Int
    let height: Int
    private(set) var pixels: [UInt32]

    init(width: Int, height: Int, gray: Int = 255) {
        self.width = width
        self.height = height
        pixels = Array(repeating: EdgeMap.pixel(red: gray, green: gray, blue: gray), count: width * height)
    }

    /// A left-to-right gray ramp from `from` to `to`.
    static func gradient(width: Int, height: Int, from: Int, to: Int) -> SyntheticBitmap {
        var bitmap = SyntheticBitmap(width: width, height: height)
        for x in 0 ..< width {
            let value = from + (to - from) * x / max(width - 1, 1)
            for y in 0 ..< height {
                bitmap.pixels[y * width + x] = EdgeMap.pixel(red: value, green: value, blue: value)
            }
        }
        return bitmap
    }

    /// Gray `gray` with ± `amplitude` of repeatable noise in each channel.
    static func noise(width: Int, height: Int, gray: Int, amplitude: Int, seed: UInt64 = 42) -> SyntheticBitmap {
        var bitmap = SyntheticBitmap(width: width, height: height)
        var state = seed
        func next() -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int(state >> 33) % (2 * amplitude + 1) - amplitude
        }
        for index in bitmap.pixels.indices {
            bitmap.pixels[index] = EdgeMap.pixel(red: gray + next(), green: gray + next(), blue: gray + next())
        }
        return bitmap
    }

    /// Fills columns `x ..< x + columns`, rows `y ..< y + rows`.
    mutating func fill(x: Int, y: Int, width columns: Int, height rows: Int, red: Int, green: Int, blue: Int) {
        for row in y ..< y + rows {
            for column in x ..< x + columns {
                pixels[row * width + column] = EdgeMap.pixel(red: red, green: green, blue: blue)
            }
        }
    }

    mutating func fill(x: Int, y: Int, width columns: Int, height rows: Int, gray: Int) {
        fill(x: x, y: y, width: columns, height: rows, red: gray, green: gray, blue: gray)
    }

    var map: EdgeMap {
        EdgeMap(width: width, height: height, pixels: pixels)
    }
}
