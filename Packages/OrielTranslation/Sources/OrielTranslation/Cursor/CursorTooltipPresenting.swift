import CoreGraphics

/// What Translate Under Cursor shows next to the pointer; `CursorTooltipPanel` on screen, a recorder in tests.
@MainActor
protocol CursorTooltipPresenting: AnyObject {
    /// Text was found and its translation is on its way.
    func showPending(region: CGRect, pointer: CGPoint)
    func show(_ translation: CursorTranslation, region: CGRect, pointer: CGPoint)
    func showFailure(_ message: String, region: CGRect, pointer: CGPoint)
    func hide()
}
