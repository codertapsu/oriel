import CoreGraphics

/// Joins boxes that touch, so neighbouring finds (the parts of a card number, the lines of a key) become one
/// region instead of a stack of overlapping ones. Pure.
nonisolated enum BoxMerger {
    /// The unions of `rects` that overlap or come within `tolerance` points of each other, until none do.
    static func merge(_ rects: [CGRect], tolerance: CGFloat) -> [CGRect] {
        var merged = rects.map(\.standardized).filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
        var changed = true
        while changed {
            changed = false
            outer: for index in merged.indices {
                for other in merged.indices where other > index {
                    if merged[index].insetBy(dx: -tolerance, dy: -tolerance).intersects(merged[other]) {
                        merged[index] = merged[index].union(merged[other])
                        merged.remove(at: other)
                        changed = true
                        break outer
                    }
                }
            }
        }
        return merged.sorted { ($0.minY, $0.minX) < ($1.minY, $1.minX) }
    }
}
