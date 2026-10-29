import CoreGraphics

/// Runs one action on the focused window of an app: reads the window, plans (`TilingPlanner`), sets the size, then
/// the position, then the size again if the window did not take it (an app may keep the size the old display allowed
/// until the window is on the new one), and reads the frame back. A window that came out another size, because of a
/// minimum or maximum size or whole-character snapping, is lined up with the layout's edges and kept on its screen
/// (`TileFitting`). What it did goes into the history, for Restore and cycling.
///
/// Synchronous, because it runs inside the AX actor: one action at a time, so a burst of key presses is handled in
/// order, each starting from where the last left the window.
nonisolated struct WindowArranger<Access: WindowAccessing> {
    let access: Access
    private(set) var history: TileHistory<Access.Key>

    init(access: Access, capacity: Int = TileHistory<Access.Key>.defaultCapacity) {
        self.access = access
        history = TileHistory(capacity: capacity)
    }

    mutating func arrange(_ action: TilingAction, pid: Int32, displays: [DisplayGeometry], options: TilingOptions) -> TilingOutcome {
        guard !displays.isEmpty else { return .unchanged }
        let window: Access.Window
        switch access.focusedWindow(of: pid) {
        case let .found(found): window = found
        case .noWindow: return .noWindow
        case .refused: return .appDidNotRespond
        }
        guard let snapshot = access.snapshot(of: window) else { return .appDidNotRespond }
        guard !snapshot.isMinimized else { return .noWindow }
        if let reason = snapshot.skipReason {
            return .skipped(reason)
        }
        let key = access.key(of: window)
        let record = history.record(for: key, at: snapshot.frame)
        let plan = TilingPlanner.plan(
            action,
            window: snapshot.frame,
            record: record,
            restoreFrame: action == .restore ? history.restoreFrame(for: key) : nil,
            displays: displays,
            options: options
        )
        switch plan {
        case .nothing:
            return .unchanged
        case let .restore(placement, display):
            guard move(window, to: placement, on: displays[display], pid: pid, snapshot: snapshot) != nil else {
                return .skipped(.notMovable)
            }
            history.forget(key)
            return .moved
        case let .place(placement, display, recorded, step):
            guard let result = move(window, to: placement, on: displays[display], pid: pid, snapshot: snapshot) else {
                return .skipped(.notMovable)
            }
            history.noteArranged(
                key, from: snapshot.frame, previous: record, action: recorded, step: step, target: placement.frame, result: result
            )
            return .moved
        }
    }

    mutating func forgetAll() {
        history.removeAll()
    }

    /// Moves the window and returns the frame it reports afterwards; nil when the app would not move it at all.
    private func move(
        _ window: Access.Window,
        to placement: TilePlacement,
        on display: DisplayGeometry,
        pid: Int32,
        snapshot: WindowSnapshot
    ) -> CGRect? {
        access.withEnhancedUserInterfaceOff(pid: pid) {
            let target = placement.frame
            guard snapshot.canResize else {
                // It keeps its size, so it goes straight to where that size lines up with the layout.
                let origin = TileFitting.fitted(placement, size: snapshot.frame.size, on: display).origin
                let moved = access.setPosition(origin, of: window)
                let actual = access.frame(of: window) ?? CGRect(origin: origin, size: snapshot.frame.size)
                return moved || Self.isSame(actual.origin, origin) ? actual : nil
            }
            access.setSize(target.size, of: window)
            let moved = access.setPosition(target.origin, of: window)
            var actual = access.frame(of: window) ?? target
            guard moved || Self.isSame(actual.origin, target.origin) else { return nil }
            if !Self.isSame(actual.size, target.size) {
                access.setSize(target.size, of: window)
                actual = access.frame(of: window) ?? actual
            }
            let origin = Self.isSame(actual.size, target.size)
                ? target.origin
                : TileFitting.fitted(placement, size: actual.size, on: display).origin
            if !Self.isSame(actual.origin, origin) {
                access.setPosition(origin, of: window)
                actual = access.frame(of: window) ?? CGRect(origin: origin, size: actual.size)
            }
            return actual
        }
    }

    private static func isSame(_ lhs: CGPoint, _ rhs: CGPoint) -> Bool {
        abs(lhs.x - rhs.x) <= TileLayout.tolerance && abs(lhs.y - rhs.y) <= TileLayout.tolerance
    }

    private static func isSame(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) <= TileLayout.tolerance && abs(lhs.height - rhs.height) <= TileLayout.tolerance
    }
}
