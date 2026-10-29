import CoreGraphics

/// What Window Tiling remembers about a window it arranged: where the window was before, for Restore, and what it last
/// did, for cycling and for taking a layout to another display.
nonisolated struct TileRecord: Sendable, Equatable {
    /// The frame the window had before Window Tiling started arranging it. A run of actions keeps the frame from
    /// before the first, so Restore undoes the whole run, as Rectangle's and Magnet's do.
    var restoreFrame: CGRect
    /// The last action, as it applies on another display: a layout moved there keeps its layout.
    var action: TilingAction
    /// The cycle step of a half (`TilingOptions.fraction(forStep:)`); 0 for the other actions.
    var step: Int
    /// The frame Window Tiling asked for.
    var target: CGRect
    /// The frame the window reported afterwards, which an app with a minimum size or one that snaps to whole
    /// characters makes different from the target.
    var result: CGRect

    /// Whether a window now at `frame` is still where Window Tiling left it, so the user has not moved it since.
    func isCurrent(at frame: CGRect) -> Bool {
        TileLayout.isSame(frame, result) || TileLayout.isSame(frame, target)
    }
}
