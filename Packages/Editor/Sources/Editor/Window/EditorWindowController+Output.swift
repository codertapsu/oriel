import AppKit
import OrielCore
import SharedUI

/// Getting the image out: clipboard, upload, `.oriel` save, export panel, drag-out, and the question asked when
/// a window with undelivered edits closes.
extension EditorWindowController {
    func copyImage() {
        guard let image = session.flattenedImage(), Pasteboard.copy(image, label: EditorLauncher.clipboardLabel) else {
            NSSound.beep()
            return
        }
        delivered()
        Toast.show("Copied", symbol: "doc.on.doc", on: window?.screen)
    }

    func upload() {
        guard let onUpload, let image = session.flattenedImage() else {
            NSSound.beep()
            return
        }
        delivered()
        onUpload(image)
    }

    /// ⌘S: writes the editable bundle, in place when the document came from one.
    func save() {
        session.commitPendingEdits()
        if let url = session.fileURL {
            writeBundle(to: url)
            return
        }
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [OrielBundle.contentType]
        panel.nameFieldStringValue = EditorExporter.fileName(for: session.title, fileExtension: OrielBundle.fileExtension)
        panel.directoryURL = session.sourceURL?.deletingLastPathComponent()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        Task { @MainActor [weak self] in
            let response = await panel.beginSheetModal(for: window)
            guard let self else { return }
            guard response == .OK, let url = panel.url else {
                closesAfterSaving = false
                return
            }
            writeBundle(to: url)
        }
    }

    func writeBundle(to url: URL) {
        do {
            try OrielBundle.write(session.document, to: url)
            session.fileURL = url
            session.sourceURL = url
            session.title = url.deletingPathExtension().lastPathComponent
            window?.title = session.title
            window?.representedURL = url
            delivered()
            Toast.show("Saved", symbol: "square.and.arrow.down", on: window?.screen)
            if closesAfterSaving {
                window?.close()
            }
        } catch {
            closesAfterSaving = false
            log.error("Saving \(url.path, privacy: .private) failed: \(error.localizedDescription, privacy: .public)")
            present(error)
        }
    }

    /// ⌘E: a save panel with a format pop-up (PNG, JPEG, HEIC, PDF), starting from the last format used here.
    func export() {
        guard let window else { return }
        session.commitPendingEdits()
        let export = ExportPanel(title: session.title, format: exportFormat, directory: session.sourceURL?.deletingLastPathComponent())
        exportPanel = export
        Task { @MainActor [weak self] in
            let response = await export.panel.beginSheetModal(for: window)
            guard let self else { return }
            exportPanel = nil
            exportFormat = export.format
            guard response == .OK, let url = export.panel.url else { return }
            writeExport(to: url, format: export.format)
        }
    }

    func writeExport(to url: URL, format: EditorExportFormat) {
        do {
            try EditorExporter.write(session.document, format: format, to: url, effects: session.effects)
            delivered()
            Toast.show("Exported", symbol: "square.and.arrow.up", on: window?.screen)
        } catch {
            log.error("Exporting to \(url.path, privacy: .private) failed: \(error.localizedDescription, privacy: .public)")
            present(error)
        }
    }

    /// The drag's file is in the default export format; the PNG rides along for apps that want image data.
    func makeDragPayload() -> DragPayload? {
        guard let image = session.flattenedImage() else { return nil }
        let scale = EditorExporter.dpiScale(of: session.document)
        let format = session.defaults.exportFormat
        guard let png = ImageFile.data(for: image, format: .png, scale: scale) else { return nil }
        let data = format == .png ? png : session.encodedData(for: format)
        guard let data else { return nil }
        let pointSize = CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        return DragPayload(
            data: data,
            fileName: EditorExporter.fileName(for: session.title, fileExtension: format.fileExtension),
            contentType: format.contentType,
            pngData: png,
            preview: NSImage(cgImage: image, size: pointSize)
        )
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        session.commitPendingEdits()
        guard session.hasUnsavedChanges else { return true }
        let alert = NSAlert()
        alert.messageText = "Save your annotations before closing?"
        alert.informativeText = "This screenshot has changes that were not saved, copied or exported."
        alert.addButton(withTitle: "Save…")
        alert.addButton(withTitle: "Don’t Save")
        alert.addButton(withTitle: "Cancel")
        Task { @MainActor [weak self] in
            let response = await alert.beginSheetModal(for: sender)
            guard let self else { return }
            switch response {
            case .alertFirstButtonReturn:
                closesAfterSaving = true
                save()
            case .alertSecondButtonReturn:
                delivered()
                sender.close()
            default:
                break
            }
        }
        return false
    }

    // MARK: - Private

    private func present(_ error: any Error) {
        guard let window else { return }
        NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
    }
}
