import AppKit
import OrielCore
import UniformTypeIdentifiers

/// The video editor (PLAN §17): Open Video… for any movie, Edit… from the finished-recording panel, and movies
/// dropped on an editor window. One window per movie; opening a movie that is open brings its window forward.
public extension RecordingCoordinator {
    /// Open Video…: asks for a movie, starting in the recordings folder, and opens it in the video editor.
    func openVideoEditor() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a movie to edit."
        panel.prompt = "Open"
        let folder = RecordingOptions(settings: settings).outputFolder
        if FileManager.default.fileExists(atPath: folder.path) {
            panel.directoryURL = folder
        }
        NSApplication.shared.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openVideo(at: url)
    }

    /// Opens `url` in the video editor, with the clicks saved beside it and any chapters it already has. When
    /// `replacing` is given (a window with nothing to lose that the movie was dropped on), the new window takes its
    /// place.
    func openVideo(at url: URL) {
        guard ProAccess.shared.check(.videoEditor) else { return }
        openVideo(at: url, replacing: nil)
    }

    internal func openVideo(at url: URL, replacing old: VideoEditorWindowController?) {
        let url = url.standardizedFileURL
        if let open = editors.first(where: { $0.session.url.standardizedFileURL == url }) {
            open.present()
            return
        }
        let autoZoom = AutoZoomSettings(
            level: settings[RecordingSettingKeys.autoZoomLevel],
            hold: settings[RecordingSettingKeys.autoZoomHold]
        )
        Task { [weak self] in
            do {
                let info = try await MovieInfo.load(url)
                let clicks: ClickSidecar?
                do {
                    clicks = try await ClickSidecar.loadInBackground(for: url)
                } catch {
                    self?.log.notice("the clicks next to the movie could not be read: \(error.localizedDescription, privacy: .public)")
                    clicks = nil
                }
                let chapters = await (try? ChapterTrack.chapters(ofMovieAt: url)) ?? []
                let edit = VideoEdit(chapters: chapters.map { ChapterMarker(time: $0.start, title: $0.title) })
                let session = VideoEditorSession(info: info, edit: edit, clicks: clicks, autoZoom: autoZoom)
                self?.present(session, replacing: old)
            } catch {
                self?.log.error("the video editor could not open a movie: \(error.localizedDescription, privacy: .public)")
                let alert = NSAlert()
                alert.messageText = "Oriel cannot open “\(url.lastPathComponent)”"
                alert.informativeText = error.localizedDescription
                NSApplication.shared.activate()
                alert.runModal()
            }
        }
    }

    private func present(_ session: VideoEditorSession, replacing old: VideoEditorWindowController?) {
        let controller = VideoEditorWindowController(session: session, settings: settings, textRecognizer: textRecognizer)
        controller.onClose = { [weak self] closed in
            self?.editors.removeAll { $0 === closed }
        }
        controller.onOpen = { [weak self] in
            self?.openVideoEditor()
        }
        controller.onOpenDropped = { [weak self] url, replacing in
            self?.openVideo(at: url, replacing: replacing)
        }
        editors.append(controller)
        controller.present(at: old?.window?.frame)
        old?.window?.close()
    }
}
