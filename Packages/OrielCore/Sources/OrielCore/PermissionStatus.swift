/// The state of one TCC permission, as far as the public APIs can tell.
public enum PermissionStatus: String, Codable, Sendable {
    case granted
    case denied
    /// Never asked, or (Accessibility, Screen Recording) not granted yet: the APIs cannot tell the two apart.
    case notDetermined
}
