import Foundation
import Observation
import SwiftUI

/// Typed, observable settings, stored in UserDefaults as JSON.
///
/// Main-actor isolated: SwiftUI panes bind to it directly (`$settings[key]` or `settings.binding(key)`), and
/// services read the values they need and pass them on. Every read touches `revision`, so a view that showed
/// any setting re-renders when any setting changes.
@MainActor
@Observable
public final class SettingsStore {
    /// Posted after every change. `userInfo["key"]` is the setting's name.
    public static let didChangeNotification = Notification.Name("com.codertapsu.oriel.settingsDidChange")

    private var revision = 0
    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public subscript<Value>(key: SettingKey<Value>) -> Value {
        get {
            _ = revision
            guard let data = defaults.data(forKey: key.name),
                  let value = try? JSONDecoder().decode(Value.self, from: data)
            else {
                return key.defaultValue
            }
            return value
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: key.name)
            didChange(key.name)
        }
    }

    /// Whether the user (or a bootstrap import) has set this key.
    public func hasValue(_ key: SettingKey<some Any>) -> Bool {
        defaults.object(forKey: key.name) != nil
    }

    public func reset(_ key: SettingKey<some Any>) {
        defaults.removeObject(forKey: key.name)
        didChange(key.name)
    }

    /// Removes every setting whose name starts with `prefix`, for "reset this pane" and for uninstall.
    public func removeAll(withPrefix prefix: String) {
        for name in defaults.dictionaryRepresentation().keys where name.hasPrefix(prefix) {
            defaults.removeObject(forKey: name)
        }
        didChange(prefix)
    }

    public func binding<Value>(_ key: SettingKey<Value>) -> Binding<Value> {
        Binding(get: { self[key] }, set: { self[key] = $0 })
    }

    private func didChange(_ name: String) {
        revision &+= 1
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self, userInfo: ["key": name])
    }
}
