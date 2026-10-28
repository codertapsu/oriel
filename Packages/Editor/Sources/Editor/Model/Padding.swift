import CoreGraphics

/// Space around the (cropped) image, in points, filled by the background.
nonisolated struct Padding: Codable, Sendable, Hashable {
    var top: CGFloat
    var left: CGFloat
    var bottom: CGFloat
    var right: CGFloat

    init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = max(top, 0)
        self.left = max(left, 0)
        self.bottom = max(bottom, 0)
        self.right = max(right, 0)
    }

    init(all value: CGFloat) {
        self.init(top: value, left: value, bottom: value, right: value)
    }

    static let zero = Padding(all: 0)

    var horizontal: CGFloat {
        left + right
    }

    var vertical: CGFloat {
        top + bottom
    }
}
