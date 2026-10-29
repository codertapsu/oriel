import AppKit
import Observation

/// The file translation window (PLAN §17, AppKit per rule 4). Oriel has no Dock icon, so showing it activates the app.
/// It follows its model through observation tracking while it is open, and nothing runs once it is closed; closing
/// it stops a translation in progress.
@MainActor
final class FileTranslationWindowController: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let model: FileTranslationModel
    private let glossaries: GlossaryLibraryModel
    private let content: FileTranslationView
    private var isObserving = false
    var onClose: (@MainActor () -> Void)?

    init(model: FileTranslationModel, glossaries: GlossaryLibraryModel, actions: FileTranslationActions) {
        self.model = model
        self.glossaries = glossaries
        content = FileTranslationView(actions: actions)
        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 880, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: true
        )
        super.init()
        content.imagePane.onShowOriginal = { [weak model] original in model?.showsOriginalImage = original }
        window.title = "Translate File"
        window.contentView = content
        window.contentMinSize = CGSize(width: 620, height: 380)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.autorecalculatesKeyViewLoop = true
        window.initialFirstResponder = content.table.focusView
        window.setFrameAutosaveName("FileTranslation")
        window.delegate = self
    }

    func show() {
        NSApp.activate()
        if !window.isVisible, !window.setFrameUsingName("FileTranslation") {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        if !isObserving {
            isObserving = true
            observe()
        }
    }

    /// Lays the window out with the model as it is, for tests and screenshots that never show it.
    func renderNow() {
        render()
        content.layoutSubtreeIfNeeded()
    }

    private func observe() {
        guard isObserving else { return }
        withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
    }

    private func render() {
        content.update(from: model, glossaries: glossaries)
        window.title = model.title
        window.representedURL = model.url
    }

    nonisolated func windowWillClose(_: Notification) {
        MainActor.assumeIsolated {
            isObserving = false
            onClose?()
        }
    }
}
