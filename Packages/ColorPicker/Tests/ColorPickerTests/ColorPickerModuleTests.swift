@testable import ColorPicker
import OrielCore
import Testing

@MainActor
struct ColorPickerModuleTests {
    @Test func theModuleHasItsID() {
        #expect(ColorPickerModule.id == .colorPicker)
    }
}
