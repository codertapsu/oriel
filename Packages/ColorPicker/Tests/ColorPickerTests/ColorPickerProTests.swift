@testable import ColorPicker
import Testing

/// The formats every web and design tool reads are free; the others are Oriel Pro (PLAN §19).
struct ColorPickerProTests {
    @Test func theEverydayFormatsAreFree() {
        #expect(Set(ColorFormat.allCases.filter { !$0.isPro }) == [.hex, .hexAlpha, .rgb, .rgba, .hsl])
    }
}
