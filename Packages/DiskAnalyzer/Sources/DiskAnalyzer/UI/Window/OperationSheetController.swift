import AppKit

/// The sheet that shows a running copy, move or removal: what it is doing, how far it is, and Cancel.
final class OperationSheetController: NSObject {
    let panel = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 440, height: 132), styleMask: [.titled], backing: .buffered, defer: true)
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let bar = NSProgressIndicator()
    private let cancelButton = NSButton(title: "Stop", target: nil, action: nil)
    private let onCancel: () -> Void
    private let kind: FileOperation.Kind

    init(kind: FileOperation.Kind, onCancel: @escaping () -> Void) {
        self.kind = kind
        self.onCancel = onCancel
        super.init()
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.stringValue = kind.verb + "…"
        detail.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingMiddle
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.keyEquivalent = "\u{1b}"
        let footer = NSStackView(views: [detail, cancelButton])
        footer.distribution = .fill
        detail.setContentHuggingPriority(.defaultLow, for: .horizontal)
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [title, bar, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 18, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            bar.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            content.widthAnchor.constraint(equalToConstant: 440),
        ])
        panel.contentView = content
    }

    func update(_ progress: FileOperationProgress) {
        bar.doubleValue = progress.fraction
        var parts: [String] = []
        if progress.totalBytes > 0 {
            parts.append("\(DiskFormat.bytes(progress.completedBytes)) of \(DiskFormat.bytes(progress.totalBytes))")
        } else if progress.totalItems > 1 {
            parts.append("\(progress.completedItems.formatted()) of \(progress.totalItems.formatted())")
        }
        if !progress.currentName.isEmpty {
            parts.append(progress.currentName)
        }
        detail.stringValue = parts.joined(separator: " · ")
        panel.setAccessibilityLabel("\(kind.verb), \(Int(progress.fraction * 100)) percent")
    }

    @objc private func cancel() {
        cancelButton.isEnabled = false
        title.stringValue = "Stopping…"
        onCancel()
    }
}
