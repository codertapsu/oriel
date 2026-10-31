import AppKit
import SharedUI

/// Oriel in the Dock while one of its windows is open (PLAN §10.1): it becomes a regular app, with a Dock icon whose
/// preview shows its windows, a menu bar and a Window menu, and goes back to the menu bar only once the last one has
/// closed. It follows AppKit's window notifications, so every standard window counts, whichever module opens it
/// (`StandardWindows`); overlays, pins and panels do not. Hidden, Oriel keeps its icon, from which it comes back.
@MainActor
final class DockPresence {
    /// A window ordered in or out changes its occlusion state, so that one notification covers showing and hiding.
    private static let changes: [Notification.Name] = [
        NSWindow.didChangeOcclusionStateNotification,
        NSWindow.didBecomeKeyNotification,
        NSWindow.willCloseNotification,
        NSWindow.didMiniaturizeNotification,
        NSWindow.didDeminiaturizeNotification,
    ]

    private var tokens: [any NSObjectProtocol] = []
    private var pendingUpdate: Task<Void, Never>?

    func start() {
        guard tokens.isEmpty else { return }
        let center = NotificationCenter.default
        for name in Self.changes {
            tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let window = note.object as? NSWindow else { return }
                MainActor.assumeIsolated {
                    guard StandardWindows.isStandard(window) else { return }
                    self?.scheduleUpdate()
                }
            })
        }
        tokens.append(center.addObserver(forName: NSApplication.didUnhideNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleUpdate() }
        })
        (NSApp as? OrielApplication)?.willActivate = { [weak self] in self?.update() }
        update()
    }

    /// On the next turn of the main actor: a window that closes is still on screen when it says so.
    private func scheduleUpdate() {
        guard pendingUpdate == nil else { return }
        pendingUpdate = Task { [weak self] in
            self?.pendingUpdate = nil
            self?.update()
        }
    }

    /// Puts Oriel in the Dock, or back in the menu bar only, as its windows say.
    func update() {
        let app = NSApplication.shared
        let isInDock = app.activationPolicy() == .regular
        let wanted = Self.isInDock(hasOpenWindows: !StandardWindows.open.isEmpty, isHidden: app.isHidden, isInDockNow: isInDock)
        guard wanted != isInDock else { return }
        app.setActivationPolicy(wanted ? .regular : .accessory)
        // Back in the menu bar only, Oriel hands the keyboard to the app before it, as an app that quits does.
        if !wanted, app.isActive, app.keyWindow == nil {
            app.deactivate()
        }
    }

    /// Whether Oriel belongs in the Dock: while one of its standard windows is open, shown or minimized. Hidden, its
    /// windows are out of sight but still open, and it stays as it was. Pure.
    nonisolated static func isInDock(hasOpenWindows: Bool, isHidden: Bool, isInDockNow: Bool) -> Bool {
        isHidden ? isInDockNow : hasOpenWindows
    }
}
