import AppKit

/// One item of a chart for VoiceOver: its name, size and share, and Press to open it.
///
/// `nonisolated` because `NSAccessibilityElement`'s initializer and actions are, and an override may not change
/// isolation. AppKit asks for accessibility on the main thread, so Press hops back with `assumeIsolated`.
final nonisolated class ChartElement: NSAccessibilityElement {
    private let press: @MainActor @Sendable () -> Void

    init(label: String, frame: CGRect, parent: NSView, press: @escaping @MainActor @Sendable () -> Void) {
        self.press = press
        super.init()
        setAccessibilityRole(.button)
        setAccessibilityLabel(label)
        setAccessibilityParent(parent)
        setAccessibilityFrameInParentSpace(frame)
    }

    override func accessibilityPerformPress() -> Bool {
        let press = press
        MainActor.assumeIsolated { press() }
        return true
    }
}
