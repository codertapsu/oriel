import AppKit

/// The sheet shown while the video editor exports (PLAN §17): the file's name, a progress bar and Cancel.
final class ExportProgressSheet: NSWindow {
    /// Cancel was pressed (or Escape).
    var onCancel: (() -> Void)?

    private let bar = NSProgressIndicator()
    private let percent = NSTextField(labelWithString: "0 %")

    init(fileName: String) {
        super.init(contentRect: CGRect(x: 0, y: 0, width: 380, height: 120), styleMask: [.titled], backing: .buffered, defer: true)
        isReleasedWhenClosed = false
        let title = NSTextField(labelWithString: "Exporting “\(fileName)”…")
        title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        title.lineBreakMode = .byTruncatingMiddle
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        bar.setAccessibilityLabel("Export progress")
        percent.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        percent.textColor = .secondaryLabelColor
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.keyEquivalent = "\u{1b}"
        let footer = NSStackView(views: [percent, NSView(), cancel])
        let stack = NSStackView(views: [title, bar, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 16, right: 20)
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
            title.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -40),
            content.widthAnchor.constraint(equalToConstant: 380),
        ])
        contentView = content
    }

    /// Shows `fraction` (0 to 1) done.
    func setProgress(_ fraction: Double) {
        bar.doubleValue = fraction
        let value = Int((fraction * 100).rounded())
        percent.stringValue = "\(value) %"
        bar.setAccessibilityValue("\(value) percent")
    }

    @objc private func cancel(_: Any?) {
        onCancel?()
    }

    override func cancelOperation(_: Any?) {
        onCancel?()
    }
}
