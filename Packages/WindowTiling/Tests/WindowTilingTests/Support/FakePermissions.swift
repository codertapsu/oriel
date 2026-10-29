import OrielCore

/// Permissions that are never granted, and that record which pane was asked for.
@MainActor
final class FakePermissions: PermissionChecking {
    private(set) var openedPanes: [PermissionKind] = []

    func status(of _: PermissionKind) -> PermissionStatus {
        .notDetermined
    }

    func request(_: PermissionKind) async -> PermissionStatus {
        .notDetermined
    }

    func openSystemSettings(for kind: PermissionKind) {
        openedPanes.append(kind)
    }
}
