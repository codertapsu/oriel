import XCTest

/// Placeholder until XCUITest drives Settings, onboarding and the editor (PLAN §14.3). UI tests use XCTest
/// because they need `XCUIApplication`.
final class OrielUITests: XCTestCase {
    func testBundleLoads() {
        XCTAssertNotNil(Bundle(for: Self.self).bundleIdentifier)
    }
}
