import AppKit

/// A menu item that runs a closure, so modules can contribute status-menu items without a target object.
///
/// `nonisolated` because NSMenuItem's initializers are, and an override may not change isolation. AppKit
/// sends menu actions on the main thread, so `run` hops back with `assumeIsolated`.
public final nonisolated class ActionMenuItem: NSMenuItem {
    private let handler: @MainActor @Sendable () -> Void

    public init(
        _ title: String,
        symbol: String? = nil,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command],
        handler: @escaping @MainActor @Sendable () -> Void
    ) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
        keyEquivalentModifierMask = modifiers
        if let symbol {
            image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        }
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        let handler = handler
        MainActor.assumeIsolated { handler() }
    }
}
