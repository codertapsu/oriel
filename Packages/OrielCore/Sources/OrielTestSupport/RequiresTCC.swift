import Foundation
import Testing

public extension Trait where Self == ConditionTrait {
    /// Runs the test only when `ORIEL_TCC_TESTS=1`: on the dev Mac or the macOS 26 VM, where the test runner has been
    /// granted Accessibility and Screen Recording. Hosted CI never sets it (PLAN §14.2).
    static var requiresTCC: Self {
        .enabled(
            if: ProcessInfo.processInfo.environment["ORIEL_TCC_TESTS"] == "1",
            "needs Accessibility/Screen Recording grants"
        )
    }
}
