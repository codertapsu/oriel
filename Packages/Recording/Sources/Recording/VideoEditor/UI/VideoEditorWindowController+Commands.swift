import AppKit
import SharedUI

/// What the video editor's keys, buttons and toolbar items do.
extension VideoEditorWindowController {
    /// Every key press, button and toolbar item ends up here. Returns whether the command applied.
    @discardableResult
    func perform(_ command: VideoEditorCommand) -> Bool {
        let time = playback.currentTime
        switch command {
        case .playPause: playback.togglePlayback()
        case .reverse: playback.reverse()
        case .stop: playback.stop()
        case .forward: playback.forward()
        case let .stepFrames(frames): playback.step(frames: frames)
        case let .stepSeconds(seconds): playback.step(seconds: seconds)
        case .goToStart: playback.seek(to: session.range.lowerBound > time - 0.01 ? 0 : session.range.lowerBound)
        case .goToEnd: playback.seek(to: session.range.upperBound < time + 0.01 ? session.duration : session.range.upperBound)
        case .setTrimStart: session.setTrimStart(at: time)
        case .setTrimEnd: session.setTrimEnd(at: time)
        case .clearTrimStart: session.clearTrimStart()
        case .clearTrimEnd: session.clearTrimEnd()
        case .addChapter: addChapter(at: time)
        case .previousChapter: jump(to: session.edit.chapter(before: time))
        case .nextChapter: jump(to: session.edit.chapter(after: time))
        case .addZoom: addZoom(at: time)
        case .autoZoom: autoZoom()
        case .delete: session.deleteSelection()
        case .deselect: session.select(nil)
        case .undo: session.undo()
        case .redo: session.redo()
        case .copyFrameText: copyFrameText()
        case .export: export()
        case .open: onOpen?()
        case .close: window?.performClose(nil)
        case .zoomTimelineIn: timeline.zoomIn()
        case .zoomTimelineOut: timeline.zoomOut()
        case .fitTimeline: timeline.fit()
        }
        return true
    }

    private func addChapter(at time: Double) {
        guard session.addChapter(at: time) != nil else {
            NSSound.beep()
            return
        }
    }

    private func addZoom(at time: Double) {
        guard session.addZoom(at: time) != nil else {
            // Inside a zoom already, or too close to the next one or the end.
            NSSound.beep()
            return
        }
    }

    private func jump(to marker: ChapterMarker?) {
        guard let marker else {
            NSSound.beep()
            return
        }
        session.select(.chapter(marker.id))
        playback.seek(to: marker.time)
    }

    private func autoZoom() {
        guard session.clicks != nil else {
            NSSound.beep()
            return
        }
        let count = session.applyAutoZoom()
        let message = count == 0 ? "No zooms: the clicks are outside the movie" : "Added \(count) zoom\(count == 1 ? "" : "s")"
        Toast.show(message, symbol: "sparkles", on: window?.screen)
    }

    /// Starts editing the chapter's title in the inspector, showing the inspector first.
    func renameChapter(_ id: UUID) {
        if let item = splitController.splitViewItems.last, item.isCollapsed {
            item.animator().isCollapsed = false
        }
        inspector.beginRenaming(id)
    }

    // MARK: Copy Text from Frame

    /// Reads the text in the frame at the playhead, copies it and shows it in a panel; says so when there is none.
    func copyFrameText() {
        guard let recognizer = textRecognizer else {
            NSSound.beep()
            return
        }
        if playback.isPlaying {
            playback.stop()
        }
        let time = playback.currentTime
        let url = session.url
        textTask?.cancel()
        textTask = Task { [weak self] in
            let panel = await FrameTextPanel.copyText(of: url, at: time, recognizer: recognizer, near: self?.window)
            guard let self, !Task.isCancelled else {
                panel?.close()
                return
            }
            textTask = nil
            guard let panel else { return }
            textPanel?.close()
            panel.onClose = { [weak self, weak panel] in
                if let self, textPanel === panel {
                    textPanel = nil
                }
            }
            textPanel = panel
        }
    }

    // MARK: Chapters as timestamps

    /// The chapters as YouTube timestamps, as an export of the current edit would have them.
    var timestamps: String {
        ChapterTimestamps.text(for: ChapterList.build(session.edit.chapters, range: session.range))
    }

    func copyTimestamps() {
        let text = timestamps
        guard !text.isEmpty, Pasteboard.copy(text) else {
            NSSound.beep()
            return
        }
        Toast.show("Copied the chapters", symbol: "doc.on.doc", on: window?.screen)
    }

    func saveTimestamps() {
        guard let window else { return }
        let text = timestamps
        guard !text.isEmpty else {
            NSSound.beep()
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(session.title) chapters.txt"
        panel.directoryURL = session.url.deletingLastPathComponent()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        Task { @MainActor [weak self] in
            guard await panel.beginSheetModal(for: window) == .OK, let url = panel.url, let self else { return }
            do {
                try await Self.write(text + "\n", to: url)
                Toast.show("Saved the chapters", symbol: "square.and.arrow.down", on: window.screen)
            } catch {
                log.error("saving the chapters failed: \(error.localizedDescription, privacy: .public)")
                NSAlert(error: error).beginSheetModal(for: window, completionHandler: nil)
            }
        }
    }

    @concurrent
    private static func write(_ text: String, to url: URL) async throws {
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    // MARK: Dropping a movie

    func openDropped(_ url: URL) {
        guard url.standardizedFileURL != session.url.standardizedFileURL else { return }
        onOpenDropped?(url, session.hasUnexportedChanges ? nil : self)
    }
}
