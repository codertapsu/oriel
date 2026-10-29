import OrielCore
import Testing
@testable import WindowTiling

@MainActor
struct WindowTilingModuleTests {
    @Test func theModuleHasItsID() {
        #expect(WindowTilingModule.id == .windowTiling)
    }
}
