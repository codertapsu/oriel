import OrielCore

/// Permissions that are never granted and never prompt.
@MainActor
final class FakePermissions: PermissionChecking {
    func status(of _: PermissionKind) -> PermissionStatus {
        .notDetermined
    }

    func request(_: PermissionKind) async -> PermissionStatus {
        .notDetermined
    }

    func openSystemSettings(for _: PermissionKind) {}
}
