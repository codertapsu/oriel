import Darwin

/// Looks up a C symbol by name. Injected so tests can pretend any symbol is missing (PLAN §13.1).
public struct SymbolResolver: Sendable {
    public let lookup: @Sendable (String) -> UnsafeMutableRawPointer?

    public init(lookup: @escaping @Sendable (String) -> UnsafeMutableRawPointer?) {
        self.lookup = lookup
    }

    /// The running system: SkyLight is opened once, then everything is resolved through RTLD_DEFAULT, which
    /// also covers HIServices (linked through ApplicationServices) and the deprecated Process Manager calls.
    public static let system: SymbolResolver = {
        _ = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        // RTLD_DEFAULT is ((void *) -2); rebuilt per call because a pointer cannot be captured as Sendable.
        return SymbolResolver { name in dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) }
    }()

    /// Resolves nothing, as on a macOS release that removed every private symbol.
    public static let none = SymbolResolver { _ in nil }
}
