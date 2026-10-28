import Foundation
import OrielTestSupport
import Testing

/// Skipped in a normal run; with `ORIEL_TCC_TESTS=1` it runs and passes, which shows the trait works both ways.
@Test(.requiresTCC)
func requiresTCCRunsOnlyWhenOptedIn() {
    #expect(ProcessInfo.processInfo.environment["ORIEL_TCC_TESTS"] == "1")
}
