import AppKit
import SharedUI

/// The shutter sound and the brief flash over what was captured (Settings → Capture).
enum CaptureFeedback {
    private static let shutter = NSSound(
        contentsOfFile: "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif",
        byReference: true
    ) ?? NSSound(named: "Grab")

    static func playShutter() {
        shutter?.stop()
        shutter?.play()
    }

    /// A white flash that fades out over `rect` (global CoreGraphics points). Skipped under Reduce Motion.
    static func flash(_ rect: CGRect) {
        guard !rect.isEmpty, !AccessibilityDisplay.current.reduceMotion else { return }
        let frame = ScreenLocator.cocoaRect(fromCG: rect)
        let panel = FloatingPanel(contentRect: frame, level: .screenSaver)
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.animationBehavior = .none
        panel.backgroundColor = .white
        panel.alphaValue = 0.7
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            panel.orderOut(nil)
        }
    }
}
