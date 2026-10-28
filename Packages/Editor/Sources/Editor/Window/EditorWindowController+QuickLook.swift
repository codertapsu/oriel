import AppKit
import Quartz
import SharedUI

/// Quick Look (PLAN §7.5): ⌘Y or the action bar's eye shows the flattened image in the system's preview panel. Quick
/// Look previews files, so the image is written as a PNG to a folder of its own in the temporary directory, removed
/// when the panel lets go of this window or the window closes.
extension EditorWindowController: @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    /// Opens the preview panel on the image as it is now, or closes the panel when it is open.
    func toggleQuickLook() {
        guard let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists(), panel.isVisible {
            panel.orderOut(nil)
            return
        }
        do {
            try writeQuickLookFile()
        } catch {
            log.error("Quick Look could not write its preview: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
            return
        }
        // The panel walks the responder chain from this window and finds this controller.
        panel.makeKeyAndOrderFront(nil)
    }

    /// Writes the flattened image, named after the document, and returns where.
    @discardableResult
    func writeQuickLookFile() throws -> URL {
        session.commitPendingEdits()
        guard let image = session.flattenedImage(),
              let data = ImageFile.data(for: image, format: .png, scale: session.document.base.scale)
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        removeQuickLookFile()
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "Oriel Quick Look", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: EditorExporter.fileName(for: session.title, fileExtension: "png"))
        try data.write(to: url, options: .atomic)
        quickLookURL = url
        return url
    }

    func removeQuickLookFile() {
        guard let url = quickLookURL else { return }
        quickLookURL = nil
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - Controlling the panel (sent along the responder chain, on the main thread)

    override nonisolated func acceptsPreviewPanelControl(_: QLPreviewPanel?) -> Bool {
        MainActor.assumeIsolated { quickLookURL != nil }
    }

    override nonisolated func beginPreviewPanelControl(_ panel: QLPreviewPanel?) {
        MainActor.assumeIsolated {
            panel?.dataSource = self
            panel?.delegate = self
            panel?.reloadData()
        }
    }

    override nonisolated func endPreviewPanelControl(_ panel: QLPreviewPanel?) {
        MainActor.assumeIsolated {
            panel?.dataSource = nil
            panel?.delegate = nil
            removeQuickLookFile()
        }
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in _: QLPreviewPanel?) -> Int {
        quickLookURL == nil ? 0 : 1
    }

    func previewPanel(_: QLPreviewPanel?, previewItemAt _: Int) -> (any QLPreviewItem)? {
        quickLookURL as NSURL?
    }

    // MARK: - QLPreviewPanelDelegate

    /// The panel zooms out of the canvas and back into it.
    func previewPanel(_: QLPreviewPanel?, sourceFrameOnScreenFor _: (any QLPreviewItem)?) -> NSRect {
        guard let window else { return .zero }
        return window.convertToScreen(canvas.convert(canvas.visibleRect, to: nil))
    }
}
