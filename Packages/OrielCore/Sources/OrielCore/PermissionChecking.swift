/// Live permission state and the ways to ask for it. The app's `PermissionCenter` implements it.
@MainActor
public protocol PermissionChecking: AnyObject, Sendable {
    func status(of kind: PermissionKind) -> PermissionStatus
    /// Shows the system prompt where one exists, and returns the state afterwards.
    func request(_ kind: PermissionKind) async -> PermissionStatus
    /// Opens the matching pane of System Settings → Privacy & Security.
    func openSystemSettings(for kind: PermissionKind)
}
