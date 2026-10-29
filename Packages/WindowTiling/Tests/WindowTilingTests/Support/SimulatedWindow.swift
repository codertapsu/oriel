import CoreGraphics
@testable import WindowTiling

/// A window as an app answers for it through Accessibility. A resize keeps the top-left corner; the size stays within
/// the window's minimum and maximum and, like a terminal's, snaps down to whole cells; and an app that keeps its
/// windows within their screen limits the height to the visible height of the display the window is on.
final class SimulatedWindow {
    enum Call: Equatable {
        case size(CGSize)
        case position(CGPoint)
    }

    let pid: Int32
    var frame: CGRect
    var role: String? = WindowSnapshot.windowRole
    var isFullScreen = false
    var isMinimized = false
    var canMove = true
    var canResize = true
    var minimumSize = CGSize.zero
    var maximumSize = CGSize(width: 100_000, height: 100_000)
    var cell: CGSize?
    /// Set to keep the height within the display the window is on.
    var keepsWithinDisplays: [DisplayGeometry]?
    private(set) var calls: [Call] = []

    init(pid: Int32 = 42, frame: CGRect) {
        self.pid = pid
        self.frame = frame
    }

    func resize(to size: CGSize) -> Bool {
        calls.append(.size(size))
        guard canResize else { return false }
        var width = min(max(size.width, minimumSize.width), maximumSize.width)
        var height = min(max(size.height, minimumSize.height), maximumSize.height)
        if let cell {
            width = (width / cell.width).rounded(.down) * cell.width
            height = (height / cell.height).rounded(.down) * cell.height
        }
        if let displays = keepsWithinDisplays, let index = DisplayArrangement.index(of: frame, in: displays) {
            height = min(height, displays[index].visibleFrame.height)
        }
        frame.size = CGSize(width: width, height: height)
        return true
    }

    func move(to origin: CGPoint) -> Bool {
        calls.append(.position(origin))
        guard canMove else { return false }
        frame.origin = origin
        return true
    }

    func clearCalls() {
        calls.removeAll()
    }
}
