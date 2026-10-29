import AppKit
import SharedUI

/// ⌘E: a save panel with the export choices below it, then a progress sheet with Cancel.
extension VideoEditorWindowController {
    /// The choices of the last export, or the movie's own codec the first time.
    var savedExportOptions: VideoExportOptions {
        var options = VideoExportOptions()
        options.format = settings[RecordingSettingKeys.editorExportFormat]
        options.codec = settings[RecordingSettingKeys.editorExportCodec] ?? session.info.codec ?? .h264
        options.size = settings[RecordingSettingKeys.editorExportSize]
        options.gif = RecordingOptions(settings: settings).gif
        return options
    }

    func export() {
        guard let window, exportTask == nil else { return }
        if playback.isPlaying {
            playback.stop()
        }
        let options = savedExportOptions
        let accessory = ExportAccessoryView(options: options, info: session.info, summary: exportSummary)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [options.format.contentType]
        panel.nameFieldStringValue = "\(session.title) (edited).\(options.format.fileExtension)"
        panel.directoryURL = session.url.deletingLastPathComponent()
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.prompt = "Export"
        panel.message = "Export the kept part of the movie, with its zooms and chapters."
        panel.accessoryView = accessory
        accessory.onFormatChange = { [weak panel] format in
            guard let panel else { return }
            panel.allowedContentTypes = [format.contentType]
            let base = (panel.nameFieldStringValue as NSString).deletingPathExtension
            panel.nameFieldStringValue = "\(base).\(format.fileExtension)"
        }
        exportAccessory = accessory
        exportPanel = panel
        Task { @MainActor [weak self] in
            let response = await panel.beginSheetModal(for: window)
            guard let self, response == .OK, let url = panel.url else { return }
            let chosen = accessory.options
            settings[RecordingSettingKeys.editorExportFormat] = chosen.format
            settings[RecordingSettingKeys.editorExportCodec] = chosen.codec
            settings[RecordingSettingKeys.editorExportSize] = chosen.size
            if chosen.format == .gif {
                settings[RecordingSettingKeys.gifMaxWidth] = chosen.gif.maxWidth
                settings[RecordingSettingKeys.gifFrameRate] = chosen.gif.frameRate
            }
            startExport(to: url, options: chosen, in: window)
        }
    }

    /// `Keeps 1:15.00 of 1:30.00 · 3 zooms · 4 chapters`, for the save panel.
    private var exportSummary: String {
        let range = session.range
        let kept = range.upperBound - range.lowerBound
        var parts: [String] = []
        if kept < session.duration - 0.01 {
            parts.append("Keeps \(Timecode.string(kept)) of \(Timecode.string(session.duration))")
        } else {
            parts.append("The whole movie, \(Timecode.string(session.duration))")
        }
        let zooms = session.edit.zoomPlan.trimmed(to: range).segments.count
        if zooms > 0 {
            parts.append("\(zooms) zoom\(zooms == 1 ? "" : "s")")
        }
        let chapters = ChapterList.build(session.edit.chapters, range: range).count
        if chapters > 0 {
            parts.append("\(chapters) chapter\(chapters == 1 ? "" : "s")")
        }
        return parts.joined(separator: " · ") + ". A GIF has no sound or chapters."
    }

    private func startExport(to url: URL, options: VideoExportOptions, in window: NSWindow) {
        guard url.standardizedFileURL != session.url.standardizedFileURL else {
            NSAlert(error: VideoEditorError.replacesSource).beginSheetModal(for: window, completionHandler: nil)
            return
        }
        let sheet = ExportProgressSheet(fileName: url.lastPathComponent)
        let request = EditedMovieExporter.Request(source: session.url, destination: url, edit: session.edit, options: options)
        let exported = session.edit
        window.beginSheet(sheet)
        let task = Task { [weak self] in
            do {
                try await EditedMovieExporter.export(request) { fraction in
                    Task { @MainActor in sheet.setProgress(fraction) }
                }
                self?.exportFinished(url, edit: exported, sheet: sheet, error: nil)
            } catch {
                self?.exportFinished(url, edit: exported, sheet: sheet, error: error)
            }
        }
        sheet.onCancel = {
            task.cancel()
        }
        exportTask = task
        updateToolbar()
    }

    private func exportFinished(_ url: URL, edit: VideoEdit, sheet: ExportProgressSheet, error: (any Error)?) {
        exportTask = nil
        window?.endSheet(sheet)
        updateToolbar()
        switch error {
        case nil:
            if session.edit == edit {
                session.markExported()
            }
            window?.subtitle = "Exported “\(url.lastPathComponent)”"
            Toast.show("Exported", symbol: "square.and.arrow.up", on: window?.screen)
            log.info("exported \(url.path, privacy: .private)")
        case is CancellationError:
            break
        case let error?:
            guard let window else { return }
            let alert = NSAlert()
            alert.messageText = "The movie could not be exported"
            alert.informativeText = error.localizedDescription
            alert.beginSheetModal(for: window, completionHandler: nil)
        }
    }
}
