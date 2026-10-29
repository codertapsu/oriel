import AppKit
import SharedUI

/// Shows `PermissionNoticeView` near the bottom of the screen under the pointer, like a toast that offers one button.
/// The panel never takes the focus, so the app in front keeps it; it goes away after `duration`, or once the button is
/// pressed. Pressing a tiling shortcut again while it shows only keeps it up for longer. Never blocks: no alert, no
/// modal session.
final class PermissionNotice {
    static let duration: Duration = .seconds(8)

    private var panel: FloatingPanel?
    private var dismissal: Task<Void, Never>?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func show(paneName: String, openSettings: @escaping @MainActor () -> Void) {
        if panel == nil, let screen = ScreenLocator.screenUnderMouse {
            let content = PermissionNoticeView(paneName: paneName) { [weak self] in
                self?.close()
                openSettings()
            }
            let background = Material.make(cornerRadius: 14)
            content.translatesAutoresizingMaskIntoConstraints = false
            background.contentView.addSubview(content)
            NSLayoutConstraint.activate([
                content.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
                content.topAnchor.constraint(equalTo: background.contentView.topAnchor),
                content.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            ])
            let panel = FloatingPanel(level: .statusBar)
            panel.contentView = background
            let size = background.fittingSize
            let visible = screen.visibleFrame
            panel.setFrame(
                CGRect(x: (visible.midX - size.width / 2).rounded(), y: visible.minY + 80, width: size.width, height: size.height),
                display: true
            )
            panel.setAccessibilityLabel(PermissionNoticeView.title)
            panel.orderFrontRegardless()
            let announcement = "\(PermissionNoticeView.title). \(PermissionNoticeView.message(paneName: paneName))"
            NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [.announcement: announcement])
            self.panel = panel
        }
        dismissal?.cancel()
        dismissal = Task { [weak self] in
            try? await Task.sleep(for: Self.duration)
            guard !Task.isCancelled else { return }
            self?.close()
        }
    }

    func close() {
        dismissal?.cancel()
        dismissal = nil
        panel?.orderOut(nil)
        panel = nil
    }
}
