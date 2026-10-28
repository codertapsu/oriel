import AppKit
import OrielCore

/// Opens image editor windows (PLAN §7.5). The app keeps one launcher and calls it from the Quick Access
/// Overlay, pins, history and file opening. Each window starts from the editor settings (default colour, width,
/// export format and background preset) as they are when it opens.
public final class EditorLauncher {
    private let settings: SettingsStore
    private var controllers: [EditorWindowController] = []
    private let log = Log.logger("editor")

    /// Wired by the app to the Upload button; the editor passes the flattened image. While nil, editor windows
    /// show no Upload button.
    public var onUpload: ((CGImage) -> Void)? {
        didSet {
            for controller in controllers {
                controller.onUpload = onUpload
            }
        }
    }

    /// - Parameter settings: read when a window opens, for the editor's defaults.
    public init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Opens an editor window for a capture (from the Quick Access Overlay, a pin or history). A capture that is
    /// already open brings its window to the front.
    public func open(_ capture: CaptureResult) {
        if let open = controllers.first(where: { $0.captureID == capture.id }) {
            open.present()
            return
        }
        present(makeSession(for: capture), captureID: capture.id)
    }

    /// Opens an image file (png/jpeg/heic/tiff…) or an `.oriel` bundle. A bundle that is already open brings its
    /// window to the front.
    /// - Throws: `OrielError.invalidArgument` when the file is not an image or an Oriel document.
    public func open(fileAt url: URL) throws {
        let url = url.standardizedFileURL
        if let open = controllers.first(where: { $0.session.fileURL == url }) {
            open.present()
            return
        }
        do {
            try present(makeSession(forFileAt: url), captureID: nil)
        } catch {
            log.error("Opening \(url.path, privacy: .private) failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    /// The number of editor windows open.
    var openWindowCount: Int {
        controllers.count
    }

    func makeSession(for capture: CaptureResult) -> EditorSession {
        let defaults = EditorDefaults(settings: settings)
        return EditorSession(
            document: EditorDocument(capture: capture, preset: defaults.backgroundPreset),
            title: Self.title(for: capture.date),
            defaults: defaults
        )
    }

    func makeSession(forFileAt url: URL) throws -> EditorSession {
        let defaults = EditorDefaults(settings: settings)
        let title = url.deletingPathExtension().lastPathComponent
        if OrielBundle.isBundle(url) {
            return try EditorSession(document: OrielBundle.read(from: url), title: title, fileURL: url, defaults: defaults)
        }
        let session = try EditorSession(
            document: EditorDocument(base: ImageImporter.load(url), preset: defaults.backgroundPreset),
            title: title,
            defaults: defaults
        )
        session.sourceURL = url
        return session
    }

    /// "Screenshot 2026-10-29 at 10.15.02", the way macOS names screenshots.
    static func title(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Screenshot \(formatter.string(from: date))"
    }

    private func present(_ session: EditorSession, captureID: UUID?) {
        let controller = EditorWindowController(session: session, captureID: captureID)
        controller.onUpload = onUpload
        controller.onClose = { [weak self] closed in
            self?.controllers.removeAll { $0 === closed }
        }
        controllers.append(controller)
        controller.present()
    }
}
