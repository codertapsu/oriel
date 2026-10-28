/// An API key read from the Keychain. Its descriptions and mirror are redacted, so a key never shows up in logs,
/// `print`, `dump` or string interpolation of a provider; only request building reads `value`.
struct APIKey: Sendable, Hashable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let value: String

    /// Nil for a missing or blank key.
    init?(_ value: String?) {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        self.value = trimmed
    }

    var description: String {
        "<redacted>"
    }

    var debugDescription: String {
        "<redacted>"
    }

    var customMirror: Mirror {
        Mirror(self, children: [])
    }
}
