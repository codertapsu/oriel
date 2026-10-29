@testable import DiskAnalyzer
import OrielCore
import Testing

@MainActor
struct DiskAnalyzerModuleTests {
    @Test func theModuleHasItsID() {
        #expect(DiskAnalyzerModule.id == .diskAnalyzer)
    }
}
