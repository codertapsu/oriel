import Foundation

/// Arranges Oriel's own window when it is in front: the same `WindowArranger`, through AppKit on the main thread
/// (`OwnWindowAccess`) instead of the AX actor, with a history of its own for Restore and cycling.
final class OwnWindowTiler {
    /// Oriel's process, whose windows `WindowMover` never touches.
    nonisolated static let ownPID = ProcessInfo.processInfo.processIdentifier

    private var arranger: WindowArranger<OwnWindowAccess>

    init(access: OwnWindowAccess = OwnWindowAccess()) {
        arranger = WindowArranger(access: access)
    }

    func arrange(_ action: TilingAction, displays: [DisplayGeometry], options: TilingOptions) -> TilingOutcome {
        arranger.arrange(action, pid: Self.ownPID, displays: displays, options: options)
    }

    func forgetAll() {
        arranger.forgetAll()
    }
}
