import AppKit
import OrielCore
import SharedUI

/// The small panel beside a running scrolling capture: what is happening, how long the result is, Done and Cancel.
/// Non-activating, so the app being captured keeps focus; like every Oriel window it is left out of the frames.
final class ScrollingCaptureHUD {
    private let panel = FloatingPanel(level: .statusBar)
    private let status = NSTextField(labelWithString: "")
    private let onDone: () -> Void
    private let onCancel: () -> Void

    init(onDone: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onDone = onDone
        self.onCancel = onCancel
        build()
    }

    /// Below the region, or above it, or inside its bottom edge when neither fits on the screen.
    func show(near region: CGRect) {
        let frame = ScreenLocator.cocoaRect(fromCG: region)
        let visible = ScreenLocator.screen(containing: region)?.visibleFrame ?? frame
        let size = panel.frame.size
        var origin = CGPoint(x: frame.midX - size.width / 2, y: frame.minY - size.height - 12)
        if origin.y < visible.minY {
            origin.y = frame.maxY + 12
            if origin.y + size.height > visible.maxY {
                origin.y = frame.minY + 12
            }
        }
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func update(_ text: String) {
        status.stringValue = text
    }

    func close() {
        panel.orderOut(nil)
    }

    private func build() {
        let background = Material.make(cornerRadius: 14)
        status.font = .systemFont(ofSize: 12, weight: .medium)
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let done = NSButton(title: "Done", target: self, action: #selector(donePressed))
        done.bezelStyle = .push
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.bezelStyle = .push
        let stack = NSStackView(views: [status, cancel, done])
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            background.widthAnchor.constraint(equalToConstant: 420),
        ])
        panel.contentView = background
        panel.setContentSize(background.fittingSize)
        panel.setAccessibilityLabel("Scrolling capture")
    }

    @objc private func donePressed() {
        onDone()
    }

    @objc private func cancelPressed() {
        onCancel()
    }
}
