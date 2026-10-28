import AppKit
import SharedUI

/// The countdown before a timed capture (PLAN §7.2, item 3): large digits in a glass panel on the screen under the
/// pointer, with a Cancel button. Each second is a one-shot sleep; nothing repeats once it is done.
final class CountdownPanel {
    private let panel = FloatingPanel(level: .statusBar)
    private let digits = NSTextField(labelWithString: "")
    private var countdown: Task<Void, any Error>?

    private init() {}

    /// Counts down `seconds` on the screen under the pointer; returns false when cancelled. The panel has gone from
    /// the screen when this returns.
    static func run(seconds: Int) async -> Bool {
        let countdown = CountdownPanel()
        let completed = await countdown.count(from: seconds)
        // The Cancel button's target is weak, and nothing else holds the countdown while it waits: without this, an
        // optimized build may free it as soon as the countdown starts, and Cancel would do nothing.
        withExtendedLifetime(countdown) {}
        return completed
    }

    private func count(from seconds: Int) async -> Bool {
        build()
        if let screen = ScreenLocator.screenUnderMouse {
            let size = panel.frame.size
            let visible = screen.visibleFrame
            panel.setFrameOrigin(CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
        }
        panel.orderFrontRegardless()
        let digits = digits
        let task = Task {
            for remaining in stride(from: seconds, to: 0, by: -1) {
                digits.stringValue = "\(remaining)"
                try await Task.sleep(for: .seconds(1))
            }
        }
        countdown = task
        let completed = await (try? task.value) != nil
        countdown = nil
        panel.animationBehavior = .none
        panel.orderOut(nil)
        if completed {
            // Give the window server a moment to take the panel off the screen before the capture.
            try? await Task.sleep(for: .milliseconds(80))
        }
        return completed
    }

    private func build() {
        let background = Material.make(cornerRadius: 28)
        digits.font = .monospacedDigitSystemFont(ofSize: 76, weight: .semibold)
        digits.alignment = .center
        digits.translatesAutoresizingMaskIntoConstraints = false
        let cancel = NSButton(title: "Cancel", target: nil, action: nil)
        cancel.bezelStyle = .push
        cancel.translatesAutoresizingMaskIntoConstraints = false
        cancel.target = self
        cancel.action = #selector(cancelPressed)
        background.contentView.addSubview(digits)
        background.contentView.addSubview(cancel)
        NSLayoutConstraint.activate([
            digits.centerXAnchor.constraint(equalTo: background.contentView.centerXAnchor),
            digits.topAnchor.constraint(equalTo: background.contentView.topAnchor, constant: 18),
            cancel.centerXAnchor.constraint(equalTo: background.contentView.centerXAnchor),
            cancel.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor, constant: -14),
            background.widthAnchor.constraint(equalToConstant: 180),
            background.heightAnchor.constraint(equalToConstant: 170),
        ])
        panel.contentView = background
        panel.setContentSize(CGSize(width: 180, height: 170))
        panel.setAccessibilityLabel("Capture countdown")
    }

    @objc private func cancelPressed() {
        countdown?.cancel()
    }
}
