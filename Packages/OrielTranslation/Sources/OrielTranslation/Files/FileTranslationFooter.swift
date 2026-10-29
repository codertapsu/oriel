import AppKit

/// The bottom of the file window: progress and status, Stop (or Resume and Translate Again), copying and Export.
@MainActor
final class FileTranslationFooter: NSView {
    private let actions: FileTranslationActions
    private let progress = NSProgressIndicator()
    private let status = NSTextField(labelWithString: "")
    private let stopButton = NSButton(title: "Stop", target: nil, action: nil)
    private let againButton = NSButton(title: "Translate Again", target: nil, action: nil)
    private let copyButton = NSButton(title: "Copy Text", target: nil, action: nil)
    private let copyImageButton = NSButton(title: "Copy Image", target: nil, action: nil)
    private let exportButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private var shownFormats: [DocumentExportFormat] = []

    init(actions: FileTranslationActions) {
        self.actions = actions
        super.init(frame: .zero)
        build()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func build() {
        progress.style = .bar
        progress.controlSize = .small
        progress.isIndeterminate = false
        progress.minValue = 0
        progress.maxValue = 1
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.widthAnchor.constraint(equalToConstant: 120).isActive = true
        progress.setAccessibilityLabel("Translation progress")
        status.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail
        status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for (button, action) in [
            (stopButton, #selector(stop)), (againButton, #selector(again)), (copyButton, #selector(copyAll)),
            (copyImageButton, #selector(copyImage)),
        ] {
            button.target = self
            button.action = action
            button.bezelStyle = .push
            button.controlSize = .regular
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
        stopButton.keyEquivalent = "."
        stopButton.keyEquivalentModifierMask = .command
        stopButton.toolTip = "Stop translating (⌘.); what is translated stays"
        exportButton.bezelStyle = .push
        exportButton.target = self
        exportButton.action = #selector(exportChosen)
        exportButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        exportButton.setAccessibilityLabel("Export")

        let stack = NSStackView()
        stack.setViews([progress, status], in: .leading)
        stack.setViews([stopButton, againButton, copyImageButton, copyButton, exportButton], in: .trailing)
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 10, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // A fixed height: a stack's edge insets give way to the split view above otherwise.
        heightAnchor.constraint(equalToConstant: 44).isActive = true
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func update(from model: FileTranslationModel) {
        let total = model.translatableCount
        progress.isHidden = !model.isBusy
        progress.doubleValue = total == 0 ? 0 : Double(model.translatedCount) / Double(total)
        progress.isIndeterminate = model.phase == .reading && total == 0
        if progress.isIndeterminate, model.isBusy {
            progress.startAnimation(nil)
        } else {
            progress.stopAnimation(nil)
        }
        status.stringValue = model.statusText
        status.toolTip = model.statusText
        // A refused file is explained in the window itself; the footer keeps its note.
        if case .failed = model.phase, model.kind != nil {
            status.textColor = .systemRed
        } else {
            status.textColor = .secondaryLabelColor
        }
        let hasFile = model.kind != nil
        stopButton.isHidden = !model.isBusy
        againButton.isHidden = model.isBusy || !hasFile || model.phase == .idle
        againButton.title = switch model.phase {
        case .finished: "Translate Again"
        case .cancelled, .failed: model.translatedCount > 0 ? "Resume" : "Try Again"
        default: "Translate Again"
        }
        let isImage = model.kind == .image
        copyImageButton.isHidden = !isImage
        copyImageButton.isEnabled = model.annotatedImage != nil
        copyButton.title = isImage ? "Copy Text" : "Copy All"
        copyButton.isHidden = !hasFile
        copyButton.isEnabled = model.translatedCount > 0
        updateExport(model.kind?.exportFormats ?? [], enabled: model.translatedCount > 0)
    }

    private func updateExport(_ formats: [DocumentExportFormat], enabled: Bool) {
        exportButton.isHidden = formats.isEmpty
        exportButton.isEnabled = enabled
        guard formats != shownFormats else { return }
        shownFormats = formats
        exportButton.removeAllItems()
        exportButton.addItem(withTitle: "Export")
        for format in formats {
            exportButton.menu?.addItem(withTitle: "\(format.title)…", action: nil, keyEquivalent: "")
        }
    }

    @objc private func stop() {
        actions.stop()
    }

    @objc private func again() {
        actions.translateAgain()
    }

    @objc private func copyAll() {
        actions.copyAll()
    }

    @objc private func copyImage() {
        actions.copyImage()
    }

    @objc private func exportChosen() {
        let index = exportButton.indexOfSelectedItem - 1
        guard shownFormats.indices.contains(index) else { return }
        actions.export(shownFormats[index])
    }
}
