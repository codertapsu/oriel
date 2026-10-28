import Foundation
import OrielTestSupport
import Testing

/// Skipped in a normal run. `ORIEL_TCC_TESTS=1 make test` forwards the flag to this hosted bundle as
/// `TEST_RUNNER_ORIEL_TCC_TESTS`, and then the test runs and passes.
@Test(.requiresTCC)
func tccOptInReachesHostedTests() {
    #expect(ProcessInfo.processInfo.environment["ORIEL_TCC_TESTS"] == "1")
}
