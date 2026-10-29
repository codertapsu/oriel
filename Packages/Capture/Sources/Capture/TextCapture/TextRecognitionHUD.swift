import AppKit
import SharedUI

/// "Reading text…" with a spinner over the area Capture Text is reading. It appears only when reading takes long
/// enough to notice, such as the first time after launch while Vision loads its models, so a quick read shows
/// nothing. Non-activating, and left out of captures like every Oriel window.
final class TextRecognitionHUD {
    /// How long reading may take before the HUD appears.
    static let delay = Duration.milliseconds(400)

    let panel = FloatingPanel(level: .statusBar)
    private let spinner = NSProgressIndicator()
    private var appearance: Task<Void, Never>?

    init() {
        build()
    }

    /// Shows the HUD over the middle of `area` (global CoreGraphics points) after `delay`, unless `hide()` comes first.
    func show(over area: CGRect) {
        appearance?.cancel()
        appearance = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled else { return }
            self?.present(over: area)
        }
    }

    func hide() {
        appearance?.cancel()
        appearance = nil
        spinner.stopAnimation(nil)
        panel.orderOut(nil)
    }

    private func present(over area: CGRect) {
        let frame = ScreenLocator.cocoaRect(fromCG: area)
        let size = panel.frame.size
        var origin = CGPoint(x: (frame.midX - size.width / 2).rounded(), y: (frame.midY - size.height / 2).rounded())
        if let visible = ScreenLocator.screen(containing: area)?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
            origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)
        }
        panel.setFrameOrigin(origin)
        spinner.startAnimation(nil)
        panel.orderFrontRegardless()
        NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [.announcement: "Reading text"])
    }

    private func build() {
        let background = Material.make(cornerRadius: 14)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        let label = NSTextField(labelWithString: "Reading text…")
        label.font = .systemFont(ofSize: 13, weight: .medium)
        let stack = NSStackView(views: [spinner, label])
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
        ])
        panel.contentView = background
        panel.setContentSize(background.fittingSize)
        panel.ignoresMouseEvents = true
        panel.setAccessibilityLabel("Reading text")
    }
}
