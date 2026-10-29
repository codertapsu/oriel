import CoreGraphics
@testable import WindowTiling

/// `WindowAccessing` over simulated windows: one focused window per app, apps that do not answer, and apps with
/// `AXEnhancedUserInterface` on, whose state is recorded at every move.
final class FakeWindowAccess: WindowAccessing {
    var focused: [Int32: SimulatedWindow] = [:]
    /// Apps that time out.
    var refusing: Set<Int32> = []
    /// Apps whose snapshot read fails after the window was found.
    var silent: Set<Int32> = []
    var enhancedUserInterface: [Int32: Bool] = [:]
    /// `AXEnhancedUserInterface` of the window's app at each size or position call.
    private(set) var enhancedStatesDuringMoves: [Bool] = []

    init(_ windows: SimulatedWindow...) {
        for window in windows {
            focused[window.pid] = window
        }
    }

    func focusedWindow(of pid: Int32) -> WindowLookup<SimulatedWindow> {
        if refusing.contains(pid) {
            return .refused
        }
        return focused[pid].map { .found($0) } ?? .noWindow
    }

    func key(of window: SimulatedWindow) -> ObjectIdentifier {
        ObjectIdentifier(window)
    }

    func snapshot(of window: SimulatedWindow) -> WindowSnapshot? {
        guard !silent.contains(window.pid) else { return nil }
        return WindowSnapshot(
            frame: window.frame,
            role: window.role,
            subrole: "AXStandardWindow",
            isFullScreen: window.isFullScreen,
            isMinimized: window.isMinimized,
            canMove: window.canMove,
            canResize: window.canResize
        )
    }

    func frame(of window: SimulatedWindow) -> CGRect? {
        window.frame
    }

    func setSize(_ size: CGSize, of window: SimulatedWindow) -> Bool {
        enhancedStatesDuringMoves.append(enhancedUserInterface[window.pid] ?? false)
        return window.resize(to: size)
    }

    func setPosition(_ origin: CGPoint, of window: SimulatedWindow) -> Bool {
        enhancedStatesDuringMoves.append(enhancedUserInterface[window.pid] ?? false)
        return window.move(to: origin)
    }

    func withEnhancedUserInterfaceOff<Result>(pid: Int32, _ body: () -> Result) -> Result {
        guard enhancedUserInterface[pid] == true else { return body() }
        enhancedUserInterface[pid] = false
        defer { enhancedUserInterface[pid] = true }
        return body()
    }
}
