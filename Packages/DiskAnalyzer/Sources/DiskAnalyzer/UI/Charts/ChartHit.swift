import CoreGraphics

/// What the pointer is over in a chart.
struct ChartHit: Equatable {
    /// The item, or `ScanNode.none` for merged smaller items.
    var node: Int32
    /// The folder the item is in.
    var parent: Int32
    var mergedCount = 0
    var mergedBytes: Int64 = 0
    /// The sunburst's center disc, which stands for the folder shown.
    var isCenter = false
    /// Where it is, for VoiceOver and to place the tip.
    var frame: CGRect = .zero
}
