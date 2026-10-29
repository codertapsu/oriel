/// What one action comes to for one window, decided by `TilingPlanner` before any Accessibility call moves it.
nonisolated enum TilingPlan: Sendable, Equatable {
    /// Move and resize the window onto display `display`. `action` and `step` are what the window's record keeps:
    /// a layout taken to another display keeps its layout.
    case place(TilePlacement, display: Int, action: TilingAction, step: Int)
    /// Put the window back to the frame it had before Window Tiling arranged it.
    case restore(TilePlacement, display: Int)
    /// Nothing to do: nothing to restore, a single display, or a window that cannot get any larger or smaller.
    case nothing
}
