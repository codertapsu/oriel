import CoreGraphics

/// Turns an action into a plan for one window: which frame, on which display, and what to remember. Pure.
///
/// - A half pressed again on the window it just placed takes the next size, ½ → ⅔ → ⅓, when cycling is on. A window
///   that already sits exactly in the ½ layout (arranged before Oriel started, say) goes straight to ⅔.
/// - Next and Previous Display take a tiled window's layout along; any other window keeps its size and place.
/// - Restore goes back to the frame from before the run of actions, wherever the window is now.
nonisolated enum TilingPlanner {
    /// - Parameters:
    ///   - record: the window's record while it is still where Window Tiling left it (`TileHistory.record(for:at:)`).
    ///   - restoreFrame: for Restore, the frame to go back to (`TileHistory.restoreFrame(for:)`).
    static func plan(
        _ action: TilingAction,
        window: CGRect,
        record: TileRecord?,
        restoreFrame: CGRect? = nil,
        displays: [DisplayGeometry],
        options: TilingOptions
    ) -> TilingPlan {
        guard let current = DisplayArrangement.index(of: window, in: displays) else { return .nothing }
        let display = displays[current]
        switch action {
        case .restore:
            guard let restoreFrame else { return .nothing }
            let frame = TileFitting.reachable(restoreFrame, displays: displays, fallback: display)
            let target = DisplayArrangement.index(of: frame, in: displays) ?? current
            return .restore(TilePlacement(frame: frame, horizontal: .start, vertical: .start), display: target)
        case .nextDisplay, .previousDisplay:
            let target = DisplayArrangement.neighbour(of: current, forward: action == .nextDisplay, in: displays)
            guard target != current else { return .nothing }
            if let record, let placement = carried(record, window: window, to: displays[target], options: options) {
                return .place(placement, display: target, action: record.action, step: record.step)
            }
            let placement = TileMotion.moved(window, from: display, to: displays[target], options: options)
            return .place(placement, display: target, action: action, step: 0)
        case .smaller, .larger:
            guard let placement = TileMotion.resized(window, on: display, larger: action == .larger, options: options) else {
                return .nothing
            }
            return .place(placement, display: current, action: action, step: 0)
        default:
            let step = cycleStep(for: action, window: window, record: record, display: display, options: options)
            guard let placement = TileLayout.placement(for: action, window: window, on: display, step: step, options: options) else {
                return .nothing
            }
            return .place(placement, display: current, action: action, step: step)
        }
    }

    /// The layout a tiled window takes to another display: the one in its record, at the same cycle step. Nil for a
    /// window whose last action depended on where it was (center, maximize height, a size step, a display move).
    static func carried(_ record: TileRecord, window: CGRect, to display: DisplayGeometry, options: TilingOptions) -> TilePlacement? {
        guard record.action.isFixedLayout else { return nil }
        return TileLayout.placement(for: record.action, window: window, on: display, step: record.step, options: options)
    }

    /// The size a half takes this time: the next one when the same half placed the window last, else ½, or ⅔ when the
    /// window is already exactly the ½ layout.
    static func cycleStep(
        for action: TilingAction,
        window: CGRect,
        record: TileRecord?,
        display: DisplayGeometry,
        options: TilingOptions
    ) -> Int {
        guard action.cyclesSizes, options.cyclesSizes else { return 0 }
        if let record {
            return record.action == action ? (record.step + 1) % TilingOptions.cycleFractions.count : 0
        }
        let first = TileLayout.placement(for: action, window: window, on: display, step: 0, options: options)
        return first.map { TileLayout.isSame($0.frame, window) } == true ? 1 : 0
    }
}
