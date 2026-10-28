import OrielCore
import Permissions
import Testing

@MainActor
struct PermissionCenterTests {
    @Test func reportsAStateForEveryPermissionWithoutPrompting() {
        let center = PermissionCenter()
        #expect(center.statuses.count == PermissionKind.allCases.count)
        #expect(Set(center.summary.keys) == Set(PermissionKind.allCases.map(\.rawValue)))
        for kind in PermissionKind.allCases {
            #expect(center.status(of: kind) == PermissionCenter.currentStatus(of: kind))
        }
    }

    @Test func onlyAccessibilityIsRequired() {
        #expect(PermissionKind.allCases.filter(\.isRequired) == [.accessibility])
    }
}
