@testable import ActivityMonitor
import OrielCore
import Testing

@MainActor
struct ActivityMonitorModuleTests {
    @Test func theModuleHasItsID() {
        #expect(ActivityMonitorModule.id == .activityMonitor)
    }
}
