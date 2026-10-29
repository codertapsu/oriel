import AppKit
import OrielCore
import SharedUI

/// What the sequence window does: delete, copy and paste a step's image, retake, annotate, the context menu, and
/// export. Edit → Copy, Paste and Delete reach it through the responder chain.
extension StepSequenceWindowController: NSMenuDelegate, NSMenuItemValidation {
    /// The steps the user means: the selection, or the row right-clicked when it is not part of it.
    var targetIDs: [UUID] {
        let steps = stepDocument.sequence.steps
        let clicked = table.clickedRow
        if clicked >= 0, !table.selectedRowIndexes.contains(clicked), steps.indices.contains(clicked) {
            return [steps[clicked].id]
        }
        return table.selectedRowIndexes.compactMap { steps.indices.contains($0) ? steps[$0].id : nil }
    }

    func deleteSelectedSteps() {
        deleteSteps(Set(targetIDs))
    }

    func deleteSteps(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let first = stepDocument.sequence.steps.firstIndex { ids.contains($0.id) } ?? 0
        edit(ids.count == 1 ? "Delete Step" : "Delete Steps") { stepDocument.remove(ids) }
        if !stepDocument.sequence.isEmpty {
            table.selectRowIndexes([min(first, stepDocument.sequence.count - 1)], byExtendingSelection: false)
        }
    }

    func retake(_ id: UUID) {
        guard let step = stepDocument.sequence.step(id) else { return }
        onRetake?(step)
    }

    func annotate(_ id: UUID) {
        guard let step = stepDocument.sequence.step(id) else { return }
        onAnnotate?(step)
    }

    func removeClick(_ id: UUID) {
        edit("Remove Click Marker") { stepDocument.removeClick(of: id) }
    }

    /// Edit → Copy: the step's image with its click marker, onto the clipboard and into Clipboard History.
    @objc func copy(_: Any?) {
        guard let id = targetIDs.first, let step = stepDocument.sequence.step(id),
              let number = stepDocument.sequence.number(of: id) else { return }
        Task {
            guard let image = await stepDocument.image(of: step) else { return }
            let marked = step.click.flatMap { StepImageRenderer.marked(image, at: $0, scale: step.scale) } ?? image
            if Pasteboard.copy(marked, label: "Step \(number)") {
                Toast.show("Copied step \(number)", symbol: "doc.on.doc")
            }
        }
    }

    /// Edit → Paste: an image on the clipboard, such as the editor's result, becomes the selected step's image.
    @objc func paste(_: Any?) {
        guard targetIDs.count == 1, let id = targetIDs.first, let pasted = StepImageReader.image(from: .general) else {
            NSSound.beep()
            return
        }
        replaceImage(of: id, with: pasted.image, scale: pasted.scale)
    }

    /// Edit → Delete.
    @objc func delete(_: Any?) {
        deleteSelectedSteps()
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(copy(_:)), #selector(delete(_:)): !targetIDs.isEmpty
        case #selector(paste(_:)): targetIDs.count == 1 && StepImageReader.canRead(.general)
        default: true
        }
    }

    // MARK: - Context menu

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let ids = targetIDs
        guard let first = ids.first, let step = stepDocument.sequence.step(first) else { return }
        if ids.count == 1 {
            menu.addItem(ActionMenuItem("Retake", symbol: "camera.viewfinder") { [weak self] in self?.retake(first) })
            if canAnnotate {
                menu.addItem(ActionMenuItem("Annotate", symbol: "pencil.tip.crop.circle") { [weak self] in self?.annotate(first) })
            }
            menu.addItem(ActionMenuItem("Copy Image", symbol: "doc.on.doc") { [weak self] in self?.copy(nil) })
            if step.click != nil {
                menu.addItem(ActionMenuItem("Remove Click Marker", symbol: "circle.slash") { [weak self] in self?.removeClick(first) })
            }
            menu.addItem(.separator())
        }
        let title = ids.count == 1 ? "Delete Step" : "Delete \(ids.count) Steps"
        menu.addItem(ActionMenuItem(title, symbol: "trash", key: "\u{8}", modifiers: []) { [weak self] in
            self?.deleteSteps(Set(ids))
        })
    }

    // MARK: - Export

    /// Asks where, then writes the export in the background.
    func export(_ format: StepExportFormat) {
        guard let window, !isExporting, !stepDocument.sequence.isEmpty else { return }
        window.makeFirstResponder(nil)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "\(fileName).\(format.fileExtension)"
        if format == .markdown {
            panel.message = "The images go in a folder next to the Markdown file."
        }
        panel.beginSheetModal(for: window) { [weak self] response in
            MainActor.assumeIsolated {
                guard response == .OK, let url = panel.url else { return }
                Task { await self?.write(format, to: url) }
            }
        }
    }

    private func write(_ format: StepExportFormat, to url: URL) async {
        isExporting = true
        defer { isExporting = false }
        let items = await stepDocument.exportItems()
        let title = stepDocument.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let details = StepExporter.Details(
            title: title.isEmpty ? "Steps" : title,
            subtitle: stepDocument.subtitle,
            accent: NSColor.controlAccentColor.usingColorSpace(.sRGB)?.cgColor ?? CGColor(srgbRed: 0, green: 0.48, blue: 1, alpha: 1),
            paper: StepPDFExporter.paperSize(for: .current)
        )
        do {
            try await Task.detached(priority: .userInitiated) {
                try StepExporter.export(items, as: format, details: details, to: url)
            }.value
            stepDocument.markExported()
            Toast.show("Exported \(url.lastPathComponent)", symbol: "square.and.arrow.up")
        } catch {
            log.error("Exporting steps failed: \(error.localizedDescription, privacy: .private)")
            guard let window else { return }
            let alert = NSAlert(error: error)
            alert.messageText = "The steps could not be exported"
            alert.informativeText = error.localizedDescription
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }

    /// The title as a file name: no slashes or colons.
    private var fileName: String {
        let title = stepDocument.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = title.isEmpty ? "Steps" : title
        return name.replacing("/", with: "-").replacing(":", with: "-")
    }
}
