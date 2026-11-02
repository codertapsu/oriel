import AppKit
import OrielCore

/// A save panel for exporting an image, with a Format pop-up (PNG, JPEG, HEIC, PDF) that keeps the file name's
/// extension in step. The editor's Export and Instant Capture's Save both use it. HEIC and PDF need Oriel Pro: while it
/// is locked they say so, and choosing one goes back to the format before and shows what Pro adds (PLAN §19).
final class ExportPanel: NSObject {
    let panel = NSSavePanel()
    private(set) var format: EditorExportFormat

    /// - Parameters:
    ///   - title: the document's title, for the file name.
    ///   - format: the format the pop-up starts on.
    ///   - directory: where the panel starts; nil leaves it to the panel.
    init(title: String, format: EditorExportFormat, directory: URL?) {
        self.format = format.isPro && !ProAccess.shared.allows(.editorDocuments) ? .png : format
        super.init()
        panel.allowedContentTypes = [self.format.contentType]
        panel.nameFieldStringValue = EditorExporter.fileName(for: title, fileExtension: self.format.fileExtension)
        panel.directoryURL = directory
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.accessoryView = makeAccessory()
    }

    @objc private func formatChanged(_ sender: NSPopUpButton) {
        let formats = EditorExportFormat.allCases
        guard formats.indices.contains(sender.indexOfSelectedItem) else { return }
        let chosen = formats[sender.indexOfSelectedItem]
        guard !chosen.isPro || ProAccess.shared.check(.editorDocuments) else {
            sender.selectItem(at: formats.firstIndex(of: format) ?? 0)
            return
        }
        format = chosen
        panel.allowedContentTypes = [format.contentType]
        let base = (panel.nameFieldStringValue as NSString).deletingPathExtension
        panel.nameFieldStringValue = "\(base).\(format.fileExtension)"
    }

    private func makeAccessory() -> NSView {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        let locked = !ProAccess.shared.allows(.editorDocuments)
        popup.addItems(withTitles: EditorExportFormat.allCases.map { $0.isPro && locked ? "\($0.title) (Pro)" : $0.title })
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
