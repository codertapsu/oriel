import AppKit
import SharedUI

/// The small glass panel at the bottom of the screen while an upload runs: where it goes, how far it is, and a
/// Cancel button. When the upload fails, or worked with something to say, the same panel shows the message, wrapped
/// and selectable (so a command such as `ssh-copy-id host` can be copied), until it is closed or a while has passed.
///
/// It never takes focus from the app in front: it is a `FloatingPanel` that becomes key only for text selection.
final class UploadProgressPanel {
    enum State: Equatable {
        case running(UploadProgress)
        case failed(String)
        case notice(String)
    }

    /// The panel's width; messages wrap inside it.
    static let width: CGFloat = 380
    /// How long a failure or a notice stays up.
    static let messageDuration: Duration = .seconds(12)

    private let panel = FloatingPanel(level: .statusBar)
    private let destinationName: String
    private let symbol: String
    private let icon = NSImageView()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    /// How much is sent. A bar that once ran indeterminate draws empty when made determinate, so there are two bars,
    /// and only one shows at a time.
    private let bar = NSProgressIndicator()
    /// "Working on it", while the size is unknown or nothing is being sent.
    private let activity = NSProgressIndicator()
    private lazy var closeButton = HUDButton(symbol: "xmark.circle.fill", label: "Cancel Upload") { [weak self] in self?.closePressed() }
    private var hiding: Task<Void, Never>?
    private(set) var state: State = .running(UploadProgress(phase: .preparing))

    /// Called when Cancel is pressed while the upload runs.
    var onCancel: (() -> Void)?
    /// Called once the panel has gone, whichever way.
    var onClose: (() -> Void)?

    init(destinationName: String, symbol: String) {
        self.destinationName = destinationName
        self.symbol = symbol
        build()
        apply(state)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var height: CGFloat {
        panel.frame.height
    }

    /// Shows the panel at the bottom of `screen`, `offset` points above the usual place, for several uploads at once.
    func show(on screen: NSScreen?, offset: CGFloat = 0) {
        guard let screen = screen ?? ScreenLocator.screenUnderMouse else { return }
        resize()
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: frame.midX - size.width / 2, y: frame.minY + 80 + offset))
        panel.orderFrontRegardless()
        NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [.announcement: title.stringValue])
    }

    func update(_ progress: UploadProgress) {
        guard case .running = state else { return }
        apply(.running(progress))
    }

    /// Shows `message` instead of the progress, then goes after `messageDuration`.
    func showFailure(_ message: String) {
        apply(.failed(message))
        announce("\(title.stringValue). \(message)")
        hideLater()
    }

    func showNotice(_ message: String) {
        apply(.notice(message))
        announce(message)
        hideLater()
    }

    func close() {
        hiding?.cancel()
        panel.orderOut(nil)
        let onClose = onClose
        self.onClose = nil
        onClose?()
    }

    // MARK: Layout

    private func build() {
        let background = Material.make(cornerRadius: 14)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        icon.translatesAutoresizingMaskIntoConstraints = false
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detail.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        detail.textColor = .secondaryLabelColor
        detail.maximumNumberOfLines = 6
        detail.isSelectable = true
        detail.preferredMaxLayoutWidth = Self.width - 100
        for indicator in [bar, activity] {
            indicator.style = .bar
            indicator.controlSize = .small
            indicator.setAccessibilityLabel("Upload progress")
        }
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        activity.isIndeterminate = true
        let text = NSStackView(views: [title, detail, bar, activity])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 4
        text.setCustomSpacing(6, after: detail)
        let row = NSStackView(views: [icon, text, closeButton])
        row.alignment = .top
        row.spacing = 10
        row.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 12, right: 8)
        row.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            row.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            row.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            background.widthAnchor.constraint(equalToConstant: Self.width),
            icon.widthAnchor.constraint(equalToConstant: 26),
            bar.widthAnchor.constraint(equalTo: text.widthAnchor),
            activity.widthAnchor.constraint(equalTo: text.widthAnchor),
            text.widthAnchor.constraint(equalToConstant: Self.width - 100),
        ])
        panel.contentView = background
        panel.setAccessibilityRole(.group)
    }

    private func apply(_ state: State) {
        self.state = state
        switch state {
        case let .running(progress):
            setIcon(symbol, color: .secondaryLabelColor)
            title.stringValue = "Uploading to \(destinationName)"
            detail.stringValue = progress.description
            if let fraction = progress.fraction {
                activity.stopAnimation(nil)
                activity.isHidden = true
                bar.doubleValue = fraction
                bar.isHidden = false
            } else {
                bar.isHidden = true
                activity.isHidden = false
                activity.startAnimation(nil)
            }
            closeButton.toolTip = "Cancel Upload"
            closeButton.setAccessibilityLabel("Cancel Upload")
            panel.allowsKey = false
        case let .failed(message):
            setIcon("exclamationmark.triangle.fill", color: .systemOrange)
            title.stringValue = destinationName.isEmpty ? "Couldn't upload" : "Couldn't upload to \(destinationName)"
            show(message: message)
        case let .notice(message):
            setIcon("checkmark.circle.fill", color: .systemGreen)
            title.stringValue = "Uploaded to \(destinationName)"
            show(message: message)
        }
        panel.setAccessibilityLabel(title.stringValue)
        resize()
    }

    private func show(message: String) {
        detail.stringValue = message
        activity.stopAnimation(nil)
        activity.isHidden = true
        bar.isHidden = true
        closeButton.toolTip = "Close"
        closeButton.setAccessibilityLabel("Close")
        // Only so the message can be selected and copied; the panel still never activates Oriel.
        panel.allowsKey = true
    }

    private func setIcon(_ name: String, color: NSColor) {
        icon.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        icon.contentTintColor = color
    }

    /// Keeps the bottom edge where it is while the height follows the content.
    private func resize() {
        guard let content = panel.contentView else { return }
        content.layoutSubtreeIfNeeded()
        let size = content.fittingSize
        var frame = panel.frame
        frame.size = CGSize(width: Self.width, height: size.height)
        panel.setFrame(frame, display: panel.isVisible)
    }

    private func announce(_ message: String) {
        NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [.announcement: message])
    }

    private func hideLater() {
        hiding?.cancel()
        hiding = Task { [weak self] in
            try? await Task.sleep(for: Self.messageDuration)
            guard !Task.isCancelled else { return }
            self?.close()
        }
    }

    private func closePressed() {
        if case .running = state {
            onCancel?()
        } else {
            close()
        }
    }
}
