import AppKit
import OrielCore
@testable import Permissions
import Testing

/// Oriel is a menu-bar app, so a grant in System Settings must show up without Oriel being activated.
@MainActor
struct PermissionRefreshTests {
    /// What the fake reader reports, changed by the tests as System Settings would.
    @MainActor
    private final class FakeTCC {
        var accessibility = PermissionStatus.notDetermined

        func status(of kind: PermissionKind) -> PermissionStatus {
            kind == .accessibility ? accessibility : .granted
        }
    }

    private let tcc = FakeTCC()
    private let local = NotificationCenter()
    private let workspace = NotificationCenter()
    private let distributed = NotificationCenter()

    private func makeCenter() -> PermissionCenter {
        let tcc = tcc
        return PermissionCenter(reader: { tcc.status(of: $0) }, local: local, workspace: workspace, distributed: distributed)
    }

    /// Observers run on the main queue; give it a turn.
    private func settle(_ duration: Duration = .milliseconds(50)) async throws {
        try await Task.sleep(for: duration)
    }

    @Test func aGrantShowsWhenAnyAppComesToTheFront() async throws {
        let center = makeCenter()
        #expect(center.status(of: .accessibility) == .notDetermined)
        tcc.accessibility = .granted
        #expect(center.status(of: .accessibility) == .notDetermined) // nothing re-read it yet
        workspace.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        try await settle()
        #expect(center.status(of: .accessibility) == .granted)
    }

    @Test func aGrantShowsShortlyAfterTheAccessibilityListChanges() async throws {
        let center = makeCenter()
        tcc.accessibility = .granted
        distributed.post(name: PermissionCenter.accessibilityListChanged, object: nil)
        try await settle(PermissionCenter.accessibilitySettleDelay + .milliseconds(300))
        #expect(center.status(of: .accessibility) == .granted)
    }

    @Test func aGrantShowsWhenOrielBecomesActive() async throws {
        let center = makeCenter()
        tcc.accessibility = .granted
        local.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        try await settle()
        #expect(center.status(of: .accessibility) == .granted)
        #expect(center.allRequiredGranted)
    }
}
