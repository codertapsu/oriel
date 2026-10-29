import AppKit
import OrielCore
import SharedUI

/// The window a finished Step Capture opens (PLAN §17): the steps in order, with thumbnails, editable titles and
/// notes, to reorder by dragging, delete, retake, annotate, and export as one tall PNG, a PDF, Markdown with an images
/// folder, or a self-contained HTML file. An image dropped or pasted onto a step replaces its image, which is how an
/// annotated step comes back from the editor. Structural edits can be undone. Closing it discards the steps, after
/// asking when they were not exported.
final class StepSequenceWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    private static let autosaveName = "OrielStepSequence"
    /// The pasteboard type of a step dragged within the list.
    static let rowType = NSPasteboard.PasteboardType("com.codertapsu.oriel.step")

    /// Asks the coordinator for a new image of a step (the same capture mode as before).
    var onRetake: ((Step) -> Void)?
    /// Hands a step's image to the editor.
    var onAnnotate: ((Step) -> Void)?
    /// Asks the coordinator for a new step at the end.
    var onAddStep: (() -> Void)?
    /// The window has closed and its document is discarded.
    var onClosed: (() -> Void)?

    let stepDocument: StepDocument
    let canAnnotate: Bool
    let table = StepTableView()
    private let titleField = NSTextField()
    private let subtitle = NSTextField(labelWithString: "")
    private let emptyNote = NSTextField(labelWithString: "No steps. Add Step captures one.")
    private let progress = NSProgressIndicator()
    private let exportButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private var confirmedClose = false
    var isExporting = false {
        didSet {
            exportButton.isEnabled = !isExporting
            if isExporting {
                progress.startAnimation(nil)
            } else {
                progress.stopAnimation(nil)
            }
        }
    }

    let log = Log.logger("capture")

    init(document stepDocument: StepDocument, canAnnotate: Bool) {
        self.stepDocument = stepDocument
        self.canAnnotate = canAnnotate
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 760, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        window.contentMinSize = CGSize(width: 620, height: 400)
        window.setFrameAutosaveName(Self.autosaveName)
        super.init(window: window)
        window.delegate = self
        window.contentView = makeContent()
        if !window.setFrameUsingName(Self.autosaveName) {
            window.center()
        }
        stepDocument.onChange = { [weak self] in self?.documentChanged() }
        stepDocument.images.onThumbnail = { [weak self] url in self?.thumbnailReady(url) }
        documentChanged()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// In front, with the first step selected unless one is.
    func show() {
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(table)
        if table.selectedRowIndexes.isEmpty, table.numberOfRows > 0 {
            table.selectRowIndexes([0], byExtendingSelection: false)
        }
    }

    /// A retake or a dropped or pasted image, which can be undone.
    func replaceImage(of id: UUID, with image: CGImage, scale: CGFloat) {
        guard stepDocument.sequence.step(id) != nil else { return }
        edit("Replace Image") { stepDocument.replaceImage(of: id, with: image, scale: scale) }
    }

    /// A new step at the end, which can be undone.
    func append(_ result: CaptureResult) {
        edit("Add Step") { stepDocument.append(result) }
        let last = stepDocument.sequence.count - 1
        table.selectRowIndexes([last], byExtendingSelection: false)
        table.scrollRowToVisible(last)
    }

    // MARK: - Undo

    /// Runs a structural change and registers its undo: the steps as they were, with the titles and notes typed since
    /// kept as they are now.
    func edit(_ name: String, _ change: () -> Void) {
        let before = stepDocument.sequence
        change()
        registerUndo(name, restoring: before)
    }

    private func registerUndo(_ name: String, restoring snapshot: StepSequence) {
        guard let undoManager = window?.undoManager else { return }
        undoManager.registerUndo(withTarget: self) { target in
            MainActor.assumeIsolated {
                let current = target.stepDocument.sequence
                target.stepDocument.restore(snapshot.keepingText(of: current))
                target.registerUndo(name, restoring: current)
            }
        }
        undoManager.setActionName(name)
    }

    // MARK: - Window

    func windowShouldClose(_: NSWindow) -> Bool {
        // An export reads the images, which closing deletes.
        guard !isExporting else {
            NSSound.beep()
            return false
        }
        guard !confirmedClose, !stepDocument.isExported, !stepDocument.sequence.isEmpty, let window else { return true }
        window.makeFirstResponder(nil)
        let count = stepDocument.sequence.count
        let alert = NSAlert()
        alert.messageText = "Close without exporting?"
        alert.informativeText = count == 1
            ? "The step is deleted when this window closes."
            : "The \(count) steps are deleted when this window closes."
        alert.addButton(withTitle: "Discard Steps")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        alert.beginSheetModal(for: window) { [weak self] response in
            MainActor.assumeIsolated {
                guard response == .alertFirstButtonReturn, let self else { return }
                self.confirmedClose = true
                self.window?.close()
            }
        }
        return false
    }

    func windowWillClose(_: Notification) {
        stepDocument.discard()
        onClosed?()
    }

    // MARK: - Changes

    private func documentChanged() {
        let selected = table.selectedRowIndexes.compactMap { index in
            stepDocument.sequence.steps.indices.contains(index) ? stepDocument.sequence.steps[index].id : nil
        }
        table.reloadData()
        let rows = IndexSet(stepDocument.sequence.steps.enumerated().filter { selected.contains($0.element.id) }.map(\.offset))
        table.selectRowIndexes(rows, byExtendingSelection: false)
        updateHeader()
    }

    /// Updates just the thumbnail, so a title being typed in that row keeps its editing.
    private func thumbnailReady(_ url: URL) {
        guard let row = stepDocument.sequence.steps.firstIndex(where: { $0.imageURL == url }),
              let view = table.view(atColumn: 0, row: row, makeIfNecessary: false) as? StepRowView
        else {
            return
        }
        let step = stepDocument.sequence.steps[row]
        view.showThumbnail(stepDocument.thumbnail(of: step), of: step)
    }

    func updateHeader() {
        let title = stepDocument.title.trimmingCharacters(in: .whitespacesAndNewlines)
        window?.title = title.isEmpty ? "Steps" : title
        if titleField.currentEditor() == nil {
            titleField.stringValue = stepDocument.title
        }
        subtitle.stringValue = stepDocument.subtitle
        emptyNote.isHidden = !stepDocument.sequence.isEmpty
        exportButton.isEnabled = !stepDocument.sequence.isEmpty && !isExporting
    }

    /// The title is saved as it is typed.
    func controlTextDidChange(_: Notification) {
        stepDocument.title = titleField.stringValue
        let title = stepDocument.title.trimmingCharacters(in: .whitespacesAndNewlines)
        window?.title = title.isEmpty ? "Steps" : title
    }

    /// Return in the title moves on to the list.
    func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        window?.makeFirstResponder(table)
        return true
    }

    @objc private func addStepPressed() {
        onAddStep?()
    }

    @objc private func exportChosen(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let format = StepExportFormat(rawValue: raw) else { return }
        export(format)
    }

    // MARK: - Building

    private func makeContent() -> NSView {
        titleField.font = .systemFont(ofSize: 20, weight: .semibold)
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.focusRingType = .exterior
        titleField.placeholderString = "Steps"
        titleField.lineBreakMode = .byTruncatingTail
        titleField.delegate = self
        titleField.setAccessibilityLabel("Title")
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [titleField, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        let addStep = NSButton(title: "Add Step", target: self, action: #selector(addStepPressed))
        addStep.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)
        addStep.imagePosition = .imageLeading
        addStep.toolTip = "Capture an area as a new step at the end"
        exportButton.addItem(withTitle: "Export")
        exportButton.item(at: 0)?.image = NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: nil)
        for format in StepExportFormat.allCases {
            let item = NSMenuItem(title: format.menuTitle, action: #selector(exportChosen(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = format.rawValue
            item.image = NSImage(systemSymbolName: format.symbol, accessibilityDescription: nil)
            exportButton.menu?.addItem(item)
        }
        exportButton.setAccessibilityLabel("Export")
        let header = NSStackView(views: [labels, progress, addStep, exportButton])
        header.spacing = 10
        header.alignment = .centerY
        header.edgeInsets = NSEdgeInsets(top: 14, left: 20, bottom: 12, right: 16)
        header.translatesAutoresizingMaskIntoConstraints = false

        configureTable()
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        emptyNote.textColor = .secondaryLabelColor
        emptyNote.font = .systemFont(ofSize: 13)
        emptyNote.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        for view in [header, separator, scroll, emptyNote] {
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.topAnchor.constraint(equalTo: content.topAnchor),
            separator.topAnchor.constraint(equalTo: header.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: separator.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            emptyNote.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyNote.centerYAnchor.constraint(equalTo: scroll.centerYAnchor),
            labels.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])
        return content
    }
}
