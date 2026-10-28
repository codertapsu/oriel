import CoreGraphics

/// Which windows the switcher shows at all (PLAN §7.1.1 item 4): standard windows and dialogs of layer 0, not
/// tiny, of apps that are not hidden by an exception.
nonisolated struct EligibilityRules: Sendable, Equatable {
    static let acceptedSubroles: Set<String> = ["AXStandardWindow", "AXDialog"]

    /// Smaller windows are helpers (macOS 27 gives every app 30-point menu-bar windows, for example).
    var minimumSize: CGSize
    var exceptions: [AppException]

    init(minimumSize: CGSize = CGSize(width: 50, height: 50), exceptions: [AppException] = AppException.defaults) {
        self.minimumSize = minimumSize
        self.exceptions = exceptions
    }

    func accepts(_ app: AppRecord) -> Bool {
        !exceptions.hidesWindows(of: app.bundleID)
    }

    /// An AX window: a standard window or a dialog, at layer 0 when the window server knows it, not tiny.
    func accepts(_ window: AXWindowRecord, layer: Int?, frame: CGRect?) -> Bool {
        if let role = window.role, role != "AXWindow" {
            return false
        }
        guard let subrole = window.subrole, Self.acceptedSubroles.contains(subrole) else { return false }
        if let layer, layer != 0 {
            return false
        }
        guard let frame = frame ?? window.frame else { return true }
        return isLargeEnough(frame)
    }

    /// A window only the server lists: layer 0, visible alpha, not tiny.
    func accepts(_ window: ServerWindowRecord) -> Bool {
        window.layer == 0 && window.alpha > 0 && isLargeEnough(window.frame)
    }

    func isLargeEnough(_ frame: CGRect) -> Bool {
        frame.width >= minimumSize.width && frame.height >= minimumSize.height
    }
}
