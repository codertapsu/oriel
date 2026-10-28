import PrivateAPIs
import Synchronization
@testable import WindowSwitcher

/// Symbolic hot keys in memory, so tests never touch the real Cmd-Tab.
final class FakeHotKeys: SymbolicHotKeyControlling {
    private let keys: Mutex<[Int32: SymbolicHotKey]>
    private let changes = Mutex<[String]>([])

    /// The system's switcher pair as found on macOS 27.0.1, plus unrelated keys.
    static let macOS27 = [
        SymbolicHotKey(id: 1, virtualKeyCode: 48, modifiers: 0x100000, isEnabled: true),
        SymbolicHotKey(id: 2, virtualKeyCode: 48, modifiers: 0x120000, isEnabled: true),
        SymbolicHotKey(id: 32, virtualKeyCode: 126, modifiers: 0x840000, isEnabled: true),
        SymbolicHotKey(id: 60, virtualKeyCode: 49, modifiers: 0x40000, isEnabled: true),
        SymbolicHotKey(id: 79, virtualKeyCode: 123, modifiers: 0x840000, isEnabled: true),
    ]

    init(_ keys: [SymbolicHotKey] = FakeHotKeys.macOS27) {
        self.keys = Mutex(Dictionary(uniqueKeysWithValues: keys.map { ($0.id, $0) }))
    }

    func symbolicHotKeys() -> [SymbolicHotKey] {
        keys.withLock { $0.values.sorted { $0.id < $1.id } }
    }

    @discardableResult
    func setSymbolicHotKey(_ id: Int32, enabled: Bool) -> Bool {
        changes.withLock { $0.append("\(id) \(enabled ? "on" : "off")") }
        return keys.withLock { keys in
            guard let key = keys[id] else { return false }
            keys[id] = SymbolicHotKey(id: id, virtualKeyCode: key.virtualKeyCode, modifiers: key.modifiers, isEnabled: enabled)
            return true
        }
    }

    func isEnabled(_ id: Int32) -> Bool {
        keys.withLock { $0[id]?.isEnabled ?? false }
    }

    /// Every switch, in order, as "1 off" / "1 on".
    var log: [String] {
        changes.withLock { $0 }
    }
}
