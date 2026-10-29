import Dispatch

/// Window Tiling's AX actor (PLAN §6.4, CLAUDE.md rule 6). Every Accessibility call of the tool runs here, on a
/// dedicated serial queue rather than the cooperative pool, because each call blocks for as long as the app in front
/// takes to answer (at most the 0.25 s messaging timeout). It also keeps the history, whose keys are AX elements, so no
/// element ever leaves the actor.
///
/// It is separate from the switcher's `AXClient`, which belongs to the switcher's runtime: Window Tiling works while the
/// switcher is off, and needs only the focused window, not observers or the window list.
actor WindowMover {
    private let queue = DispatchSerialQueue(label: "com.codertapsu.oriel.tiling.ax", qos: .userInitiated)
    private var arranger = WindowArranger(access: AXWindowAccess())

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    func arrange(_ action: TilingAction, pid: Int32, displays: [DisplayGeometry], options: TilingOptions) -> TilingOutcome {
        arranger.arrange(action, pid: pid, displays: displays, options: options)
    }

    /// Drops every record, when the tool is turned off.
    func forgetAll() {
        arranger.forgetAll()
    }
}
