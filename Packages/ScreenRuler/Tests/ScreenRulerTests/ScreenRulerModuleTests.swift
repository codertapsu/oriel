import OrielCore
@testable import ScreenRuler
import Testing

@MainActor
struct ScreenRulerModuleTests {
    @Test func theModuleHasItsID() {
        #expect(ScreenRulerModule.id == .screenRuler)
    }
}
