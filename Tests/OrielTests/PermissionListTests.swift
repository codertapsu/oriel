@testable import Oriel
import OrielCore
import Testing

/// The welcome window and Settings → Permissions come before macOS's requests, so their buttons say Continue, not
/// Grant (App Review Guidelines 5.1.1(iv)); a permission the user turned down only changes in System Settings.
@MainActor
struct PermissionListTests {
    @Test func theButtonBeforeARequestSaysContinue() {
        #expect(PermissionList.buttonTitle(for: .notDetermined) == "Continue")
        #expect(PermissionList.buttonTitle(for: .denied) == "Open System Settings…")
    }
}
