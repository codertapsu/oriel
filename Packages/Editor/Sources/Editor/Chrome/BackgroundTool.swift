import AppKit
import Observation
import OrielCore
import UniformTypeIdentifiers

/// What the background panel does beyond the session's own commands: fetch the desktop picture, let the user choose
/// an image, and save and apply presets. Pictures are decoded off the main thread; what went wrong is said in
/// `message`, in the panel.
@Observable
final class BackgroundTool {
    let session: EditorSession
    let library: BackgroundLibrary?
    private(set) var message: String?
    private(set) var isLoading = false
    @ObservationIgnored let previews = BackgroundPreviews()
    /// The editor window, for the open panel's sheet and the screen whose desktop picture to use.
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored private let log = Log.logger("editor")

    init(session: EditorSession, library: BackgroundLibrary?) {
        self.session = session
        self.library = library
    }

    /// Fills the background with the desktop picture of the window's screen, if Oriel may read it without asking.
    func useDesktopPicture() async {
        isLoading = true
        defer { isLoading = false }
        switch await DesktopPicture.load(for: window?.screen) {
        case let .success(image):
            message = nil
            session.setBackgroundImage(ImageAsset(image: image), source: .desktopPicture)
        case let .failure(failure):
            message = failure.message
        }
    }

    /// Asks for an image in an open panel (attached to the window), then fills the background with it.
    func choosePicture() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a picture for the background."
        panel.prompt = "Use Picture"
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { await self?.usePicture(at: url) }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    func usePicture(at url: URL) async {
        isLoading = true
        defer { isLoading = false }
        guard let image = await Task.detached(priority: .userInitiated, operation: { PictureLoader.load(url) }).value else {
            message = "“\(url.lastPathComponent)” isn’t an image Oriel can read."
            return
        }
        message = nil
        session.setBackgroundImage(ImageAsset(image: image), source: .file)
    }

    /// Applies a saved preset; one with a picture loads it first.
    func apply(_ preset: SavedBackground) async {
        guard let library else { return }
        isLoading = true
        defer { isLoading = false }
        let screen = window?.screen
        let style = await library.style(for: preset) {
            if case let .success(image) = await DesktopPicture.load(for: screen) {
                return image
            }
            return nil
        }
        guard let style else {
            message = "The picture of “\(preset.name)” can’t be read any more."
            return
        }
        message = nil
        session.applyBackground(style, padding: preset.padding)
    }

    /// Saves the current background as a preset named `name`.
    func saveCurrent(named name: String) async {
        guard let library, let style = session.document.background else { return }
        await library.save(name: name, style: style, padding: session.document.canvasPadding?.top ?? 0)
        log.info("Saved a background preset")
    }

    func deletePreset(_ preset: SavedBackground) {
        library?.delete(preset.id)
    }

    func dismissMessage() {
        message = nil
    }
}
