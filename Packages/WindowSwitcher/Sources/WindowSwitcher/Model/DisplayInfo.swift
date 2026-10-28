import CoreGraphics

/// One active display: its CoreGraphics id, its UUID (how SkyLight names displays) and its global bounds.
nonisolated struct DisplayInfo: Sendable, Equatable, Hashable {
    var id: UInt32
    var uuid: String?
    /// Global CoreGraphics coordinates (points, top-left origin).
    var bounds: CGRect

    init(id: UInt32, uuid: String? = nil, bounds: CGRect) {
        self.id = id
        self.uuid = uuid
        self.bounds = bounds
    }

    /// 1-based numbers from left to right, then top to bottom, for "Display 2" badges.
    static func numbers(for displays: [DisplayInfo]) -> [UInt32: Int] {
        let ordered = displays.sorted { lhs, rhs in
            lhs.bounds.minX == rhs.bounds.minX ? lhs.bounds.minY < rhs.bounds.minY : lhs.bounds.minX < rhs.bounds.minX
        }
        var numbers: [UInt32: Int] = [:]
        for (index, display) in ordered.enumerated() {
            numbers[display.id] = index + 1
        }
        return numbers
    }
}
