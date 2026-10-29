import AppKit
import OrielCore
import SharedUI

/// What happens to a capture afterwards: the after-capture action, Quick Access and pin actions, "Copy Text", and
/// history with background OCR indexing.
extension CaptureCoordinator {
    /// How many HDR images are kept for saving as HEIC.
    private static let hdrLimit = 4
    /// What Clipboard History calls a capture.
    private static let clipboardLabel = "Screenshot"

    func deliver(_ captured: CapturedImage) {
        let result = captured.result
        remember(hdrImage: captured.hdrImage, for: result.id)
        if settings[CaptureSettings.playsSound] {
            CaptureFeedback.playShutter()
        }
        if settings[CaptureSettings.flashes] {
            CaptureFeedback.flash(result.rect)
        }
        // Onto the clipboard before anything else, so the capture is in Clipboard History however the card is closed.
        let copied = settings[CaptureSettings.copiesToClipboard] && Pasteboard.copy(result.image, label: Self.clipboardLabel)
        switch captured.intent {
        case .copy:
            copy(result, alreadyCopied: copied)
        case .save:
            saveShowingToast(result)
        case .capture, .alternate:
            switch settings[CaptureSettings.afterCapture] {
            case .quickAccess: present(result)
            case .copy: copy(result, alreadyCopied: copied)
            case .save: saveShowingToast(result)
            case .annotate: annotate(result)
            }
        }
        addToHistory(result)
    }

    func perform(_ action: QuickAccessAction, on result: CaptureResult) {
        switch action {
        case .copy: copy(result)
        case .save: saveShowingToast(result)
        case .annotate: annotate(result)
        case .translate: actions?.translate(result)
        case .upload: actions?.upload(result)
        case .pin: pin(result)
        case .copyText: Task { await copyText(of: result) }
        case .close: break
        }
    }

    /// The pin commands that hand the capture on; the pin controller handles the rest.
    func perform(_ command: PinCommand, on result: CaptureResult) {
        switch command {
        case .copy: copy(result)
        case .save: saveShowingToast(result)
        case .annotate: annotate(result)
        default: break
        }
    }

    func perform(_ command: HistoryCommand, on entry: HistoryEntry) {
        if command == .reveal {
            NSWorkspace.shared.activateFileViewerSelecting([history.imageURL(for: entry)])
            return
        }
        guard let image = history.loadImage(for: entry) else {
            NSSound.beep()
            return
        }
        let result = CaptureResult(
            id: entry.id,
            image: image,
            kind: entry.kind,
            rect: entry.rect,
            scale: entry.scale,
            date: entry.date,
            windowTitle: entry.windowTitle,
            appName: entry.appName
        )
        switch command {
        case .open: present(result)
        case .copy: copy(result)
        case .save: saveShowingToast(result)
        case .pin: pin(result)
        case .annotate: annotate(result)
        case .reveal: break
        }
    }

    /// Copies the capture and says so; `alreadyCopied` only says so, for a capture `deliver` has just copied.
    func copy(_ result: CaptureResult, alreadyCopied: Bool = false) {
        if alreadyCopied || Pasteboard.copy(result.image, label: Self.clipboardLabel) {
            Toast.show("Copied", symbol: "doc.on.doc")
        }
    }

    func saveShowingToast(_ result: CaptureResult) {
        do {
            let url = try save(result, to: nil)
            Toast.show("Saved to \(url.deletingLastPathComponent().lastPathComponent)", symbol: "square.and.arrow.down")
        } catch {
            log.error("Saving failed: \(error.localizedDescription, privacy: .private)")
            Toast.show("The capture could not be saved", symbol: "exclamationmark.triangle")
        }
    }

    /// Opens the editor, or shows Quick Access when the app has not connected one.
    func annotate(_ result: CaptureResult) {
        if let actions {
            actions.annotate(result)
        } else {
            present(result)
        }
    }

    /// "Copy Text": OCR in fast mode, lines joined, onto the clipboard.
    func copyText(of result: CaptureResult) async {
        guard let textRecognizer else { return }
        do {
            let blocks = try await textRecognizer.recognize(result.image, mode: .fast, languages: [])
            let text = blocks.map(\.text).joined(separator: "\n")
            if text.isEmpty {
                Toast.show("No text found", symbol: "text.viewfinder")
            } else if Pasteboard.copy(text) {
                Toast.show("Copied the text", symbol: "text.viewfinder")
            }
        } catch {
            log.error("Text recognition failed: \(error.localizedDescription, privacy: .private)")
            Toast.show("The text could not be read", symbol: "exclamationmark.triangle")
        }
    }

    // MARK: - History

    func addToHistory(_ result: CaptureResult) {
        guard settings[CaptureSettings.historyEnabled] else { return }
        let store = history
        let days = settings[CaptureSettings.historyRetentionDays]
        Task {
            do {
                try await store.add(result)
                try await store.prune(keepingDays: days)
            } catch {
                log.error("Adding to history failed: \(error.localizedDescription, privacy: .private)")
            }
            await historyModel?.reload()
            indexPendingHistory()
        }
    }

    /// Reads the text of every capture history has not indexed yet, one at a time at utility QoS, so history can be
    /// searched by it (PLAN §17). It runs after each capture and when the history window opens, which is how
    /// captures kept before indexing existed are read: lazily, and once, since the text is stored with the entry
    /// (empty when there is none, or when OCR failed). One run at a time; a capture added meanwhile is picked up by
    /// the same run.
    func indexPendingHistory() {
        guard indexing == nil, let recognizer = textRecognizer else { return }
        let store = history
        historyModel?.isIndexing = true
        indexing = Task.detached(priority: .utility) { [weak self] in
            var tried: Set<UUID> = []
            while !Task.isCancelled, let entry = await store.unindexed().first(where: { !tried.contains($0.id) }) {
                tried.insert(entry.id)
                guard let image = store.loadImage(for: entry) else { continue }
                let text = await Self.searchableText(in: image, using: recognizer)
                try? await store.setRecognizedText(text, for: entry.id)
                await self?.historyModel?.reload()
            }
            await self?.indexingFinished()
        }
    }

    /// The text of a capture for search: paragraphs (`OCRMode.document`), a tall or wide capture tile by tile.
    nonisolated static func searchableText(in image: CGImage, using recognizer: any TextRecognizing) async -> String {
        var texts: [String] = []
        for tile in TextTiles.rects(width: image.width, height: image.height) {
            guard let part = tile.size == CGSize(width: image.width, height: image.height) ? image : image.cropping(to: tile) else {
                continue
            }
            let blocks = await (try? recognizer.recognize(part, mode: .document, languages: [])) ?? []
            texts += blocks.map(\.text)
        }
        return texts.joined(separator: "\n")
    }

    func clearHistory() {
        let store = history
        Task {
            try? await store.removeAll()
            await historyModel?.reload()
        }
    }

    func makeHistoryModel() -> HistoryModel {
        let model = HistoryModel(store: history)
        model.perform = { [weak self] command, entry in
            self?.perform(command, on: entry)
        }
        return model
    }

    // MARK: - Building blocks

    func makeQuickAccess() -> QuickAccessController {
        let settings = settings
        let controller = QuickAccessController(settings: settings) { [weak self] result in
            let format = settings[CaptureSettings.format]
            let name = FilenameTemplate.render(
                settings[CaptureSettings.filenameTemplate],
                context: FilenameTemplate.Context(result: result)
            )
            let hdrImage = format == .heic && settings[CaptureSettings.keepsHDR] ? self?.hdrImages[result.id] : nil
            return PromisedImageFile(image: result.image, hdrImage: hdrImage, format: format, scale: result.scale, baseName: name)
        }
        controller.perform = { [weak self] action, result in
            self?.perform(action, on: result)
        }
        controller.windowsChanged = { [weak self] in
            self?.cache.invalidate()
        }
        return controller
    }

    func makePins() -> PinController {
        let permissions = permissions
        let controller = PinController { permissions.status(of: .accessibility) == .granted }
        controller.perform = { [weak self] command, result in
            self?.perform(command, on: result)
        }
        controller.windowsChanged = { [weak self] in
            self?.cache.invalidate()
        }
        return controller
    }

    private func indexingFinished() async {
        indexing = nil
        historyModel?.isIndexing = false
        await historyModel?.reload()
    }

    private func remember(hdrImage: CGImage?, for id: UUID) {
        guard let hdrImage else { return }
        hdrImages[id] = hdrImage
        hdrOrder.append(id)
        while hdrOrder.count > Self.hdrLimit {
            hdrImages[hdrOrder.removeFirst()] = nil
        }
    }
}
