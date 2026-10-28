import AppKit

/// A short message ("Copied", "Saved to Desktop") near the bottom of a screen, gone after `duration`.
public enum Toast {
    public static func show(
        _ message: String,
        symbol: String = "checkmark.circle",
        on screen: NSScreen? = nil,
        duration: Duration = .seconds(1.6)
    ) {
        guard let screen = screen ?? ScreenLocator.screenUnderMouse else { return }
        let panel = FloatingPanel(level: .statusBar)
        let background = Material.make(cornerRadius: 14)
        let label = NSTextField(labelWithString: message)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        let stack = NSStackView(views: [icon, label])
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
        ])
        panel.contentView = background
        let size = background.fittingSize
        let frame = screen.visibleFrame
        panel.setFrame(CGRect(x: frame.midX - size.width / 2, y: frame.minY + 80, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        panel.setAccessibilityLabel(message)
        NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [.announcement: message])
        Task { @MainActor in
            try? await Task.sleep(for: duration)
            panel.orderOut(nil)
        }
    }
}
