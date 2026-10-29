import AppKit
import Quartz

/// Quick Look (Space, ⌘Y or the toolbar's eye) of the selected files, in the system's preview panel. Files that are
/// only in the cloud are left out: previewing one would download it.
extension DiskWindowController: @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    func quickLook() {
        guard let panel = QLPreviewPanel.shared() else { return }
        if QLPreviewPanel.sharedPreviewPanelExists(), panel.isVisible {
            panel.orderOut(nil)
            return
        }
        quickLookURLs = previewableURLs()
        guard !quickLookURLs.isEmpty else {
            NSSound.beep()
            return
        }
        // The panel walks the responder chain from this window and finds this controller.
        panel.makeKeyAndOrderFront(nil)
    }

    /// Follows the selection while the panel is open.
    func updateQuickLook() {
        guard QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(), panel.isVisible,
              panel.dataSource === self else { return }
        let urls = previewableURLs()
        guard urls != quickLookURLs, !urls.isEmpty else { return }
        quickLookURLs = urls
        panel.reloadData()
    }

    private func previewableURLs() -> [URL] {
        guard let tree = model.tree else { return [] }
        return model.actionableSelection.filter { !tree[$0].flags.contains(.cloudOnly) }.prefix(200).map(model.url(of:))
    }

    override nonisolated func acceptsPreviewPanelControl(_: QLPreviewPanel?) -> Bool {
        MainActor.assumeIsolated { !quickLookURLs.isEmpty }
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
        }
    }

    func numberOfPreviewItems(in _: QLPreviewPanel?) -> Int {
        quickLookURLs.count
    }

    func previewPanel(_: QLPreviewPanel?, previewItemAt index: Int) -> (any QLPreviewItem)? {
        quickLookURLs.indices.contains(index) ? quickLookURLs[index] as NSURL : nil
    }
}
