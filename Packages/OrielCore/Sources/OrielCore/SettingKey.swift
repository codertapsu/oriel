/// A typed setting: its UserDefaults name and the value it has until someone changes it.
///
/// Two keys are equal when their names are, so a key can be used as a subscript in a key path, which is
/// what lets SwiftUI bind to it (`$settings[SomeKeys.width]`).
public struct SettingKey<Value: Codable & Sendable>: Hashable, Sendable {
    public let name: String
    public let defaultValue: Value

    public init(_ name: String, default defaultValue: Value) {
        self.name = name
        self.defaultValue = defaultValue
    }

    public static func == (lhs: SettingKey, rhs: SettingKey) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
