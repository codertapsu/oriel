import AppKit

/// A save panel for exporting an image, with a Format pop-up (PNG, JPEG, HEIC, PDF) that keeps the file name's
/// extension in step. The editor's Export and Instant Capture's Save both use it.
final class ExportPanel: NSObject {
    let panel = NSSavePanel()
    private(set) var format: EditorExportFormat

    /// - Parameters:
    ///   - title: the document's title, for the file name.
    ///   - format: the format the pop-up starts on.
    ///   - directory: where the panel starts; nil leaves it to the panel.
    init(title: String, format: EditorExportFormat, directory: URL?) {
        self.format = format
        super.init()
        panel.allowedContentTypes = [format.contentType]
        panel.nameFieldStringValue = EditorExporter.fileName(for: title, fileExtension: format.fileExtension)
        panel.directoryURL = directory
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.accessoryView = makeAccessory()
    }

    @objc private func formatChanged(_ sender: NSPopUpButton) {
        let formats = EditorExportFormat.allCases
        guard formats.indices.contains(sender.indexOfSelectedItem) else { return }
        format = formats[sender.indexOfSelectedItem]
        panel.allowedContentTypes = [format.contentType]
        let base = (panel.nameFieldStringValue as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(base).\(format.fileExtension)"
    }

    private func makeAccessory() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: EditorExportFormat.allCases.map(\.title))
        popup.selectItem(at: EditorExportFormat.allCases.firstIndex(of: format) ?? 0)
        popup.target = self
        popup.action = #selector(formatChanged(_:))
        popup.setAccessibilityLabel("Format")
        let label = NSTextField(labelWithString: "Format:")
        let stack = NSStackView(views: [label, popup])
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        stack.frame.size = stack.fittingSize
        return stack
    }
}
