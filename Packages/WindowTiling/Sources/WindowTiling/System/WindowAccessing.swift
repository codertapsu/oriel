import CoreGraphics

/// The Accessibility calls Window Tiling makes on the focused window of the app in front. `AXWindowAccess` makes them
/// for real; tests give `WindowArranger` simulated windows with minimum sizes, snapping and slow apps. Only the AX actor
/// (`WindowMover`) calls a real one.
nonisolated protocol WindowAccessing {
    associatedtype Window
    /// Identifies a window across actions, for Restore and cycling.
    associatedtype Key: Hashable

    func focusedWindow(of pid: Int32) -> WindowLookup<Window>
    func key(of window: Window) -> Key
    /// Nil when the app did not answer.
    func snapshot(of window: Window) -> WindowSnapshot?
    func frame(of window: Window) -> CGRect?
    @discardableResult
    func setSize(_ size: CGSize, of window: Window) -> Bool
    @discardableResult
    func setPosition(_ origin: CGPoint, of window: Window) -> Bool
    /// Runs `body` with the app's `AXEnhancedUserInterface` off when it was on, and turns it back on afterwards.
    /// Chromium and Electron apps animate every frame change while it is on, so a move would land late and short.
    func withEnhancedUserInterfaceOff<Result>(pid: Int32, _ body: () -> Result) -> Result
}
