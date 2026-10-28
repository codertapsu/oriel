import Foundation

/// Errors shared across packages. Feature packages add their own where the cases are theirs alone.
public enum OrielError: LocalizedError, Sendable, Equatable {
    case permissionMissing(PermissionKind)
    case keychain(OSStatus)
    case notAvailable(String)
    case invalidArgument(String)
    case cancelled
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case let .permissionMissing(kind): "Oriel needs the \(kind.displayName) permission for this."
        case let .keychain(status): "Keychain error \(status)."
        case let .notAvailable(what): "\(what) is not available on this Mac."
        case let .invalidArgument(message): message
        case .cancelled: "Cancelled."
        case let .failed(message): message
        }
    }
}
