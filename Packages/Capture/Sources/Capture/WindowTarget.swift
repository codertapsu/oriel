import CoreGraphics

/// A window that window mode can highlight and capture, taken from the cached `SCShareableContent` and ordered front
/// to back (PLAN §7.2, item 3).
nonisolated struct WindowTarget: Sendable, Equatable, Identifiable {
    let id: CGWindowID
    /// Global CoreGraphics points.
    let frame: CGRect
    let title: String?
    let appName: String?
    let processID: pid_t

    /// The frontmost of `windows` (ordered front to back) under `point`.
    static func topmost(at point: CGPoint, in windows: [Self]) -> Self? {
        windows.first { $0.frame.contains(point) }
    }

    /// `windows` sorted by `order` (window numbers front to back); windows missing from `order` keep their relative
    /// order after the others.
    static func sorted(_ windows: [Self], byFrontToBack order: [CGWindowID]) -> [Self] {
        var rank: [CGWindowID: Int] = [:]
        for (index, id) in order.enumerated() where rank[id] == nil {
            rank[id] = index
        }
        return windows.enumerated()
            .sorted { lhs, rhs in
                let left = rank[lhs.element.id] ?? (order.count + lhs.offset)
                let right = rank[rhs.element.id] ?? (order.count + rhs.offset)
                return left < right
            }
            .map(\.element)
    }
}
