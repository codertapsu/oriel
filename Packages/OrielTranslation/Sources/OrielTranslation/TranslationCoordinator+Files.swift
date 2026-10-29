import AppKit
import OCR
import OrielCore
import SharedUI

/// Translating files (PLAN §17): "Translate File…" and files dropped on the side panel or the file window. The file is
/// read part by part (a PDF page by page) off the main thread; each part's text is translated in chunks that respect
/// the provider's limits, with progress, Stop and partial results; the window exports the result.
extension TranslationCoordinator {
    /// Beyond this many characters, a file sent to a provider that bills is confirmed first.
    static let largeFileCharacters = 100_000

    /// The open panel for "Translate File…".
    func chooseFileToTranslate() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = DocumentKind.openableTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Translate"
        panel.message = "Choose an image, PDF, text, Markdown, Word, RTF, HTML or subtitle file to translate."
        NSApp.activate()
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.translateFiles([url])
        }
    }

    /// Opens the first file in the file window and translates it.
    func translateFiles(_ urls: [URL]) {
        guard let url = urls.first else {
            showFileWindow()
            return
        }
        showFileWindow()
        if urls.count > 1 {
            Toast.show("Translating “\(url.lastPathComponent)”. Drop the others one at a time.", symbol: "doc.on.doc")
        }
        startFileTranslation(url)
    }

    @discardableResult
    func showFileWindow() -> FileTranslationWindowController {
        let model = fileTranslationModel()
        let window = fileWindow ?? FileTranslationWindowController(model: model, glossaries: glossaries, actions: fileActions())
        fileWindow = window
        window.onClose = { [weak self] in self?.stopFileTranslation() }
        window.show()
        return window
    }

    func fileTranslationModel() -> FileTranslationModel {
        if let fileModel {
            return fileModel
        }
        let target = LanguageCatalog.language(for: settings[TranslationKeys.targetLanguage])
        let model = FileTranslationModel(
            providerID: registry.preferredProvider(forTarget: LanguageCatalog.code(for: target)), targetLanguage: target
        )
        model.providers = providerChoices()
        fileModel = model
        return model
    }

    /// Reads `url` from the start and translates it, replacing whatever the window showed.
    func startFileTranslation(_ url: URL) {
        let model = fileTranslationModel()
        stopFileTranslation()
        model.providers = providerChoices()
        guard let kind = DocumentKind.of(url) else {
            let name = url.pathExtension.isEmpty ? "“\(url.lastPathComponent)”" : ".\(url.pathExtension) files"
            model.refuse(
                url,
                message: "Oriel can't translate \(name). It reads images, PDFs, text, Markdown, Word, RTF, HTML and subtitles."
            )
            return
        }
        model.open(url, kind: kind)
        runFileJob(model, url: url, kind: kind, reading: true)
    }

    /// Stops the current file translation; what was translated stays.
    func stopFileTranslation() {
        fileGeneration &+= 1
        fileTask?.cancel()
        fileTask = nil
        if let fileModel, fileModel.isBusy {
            fileModel.phase = .cancelled
        }
    }

    /// Starts a job. `reading` reads the file (again); otherwise the segments already read are translated.
    func runFileJob(_ model: FileTranslationModel, url: URL, kind: DocumentKind, reading: Bool) {
        fileGeneration &+= 1
        let job = FileTranslationJob(generation: fileGeneration)
        fileTask = Task { [weak self] in
            await self?.perform(job, model: model, url: url, kind: kind, reading: reading)
        }
    }

    private func perform(_ job: FileTranslationJob, model: FileTranslationModel, url: URL, kind: DocumentKind, reading: Bool) async {
        do {
            if reading {
                let hint = settings[TranslationKeys.sourceLanguage].trimmingCharacters(in: .whitespaces)
                let parts = DocumentReader.parts(of: url, kind: kind, recognizer: textRecognizer, languages: hint.isEmpty ? [] : [hint])
                for try await part in parts {
                    guard isCurrent(job) else { return }
                    model.append(part)
                    if part.image != nil {
                        await sampleImageColors(model)
                    }
                    try await translatePending(part.segments, of: model, job: job)
                    if let page = model.currentPage, let count = model.pageCount, page < count, isCurrent(job) {
                        model.phase = .reading
                    }
                }
                // A stopped job ends the stream early rather than with an error: then the file was not read to the end.
                guard isCurrent(job) else { return }
                model.isComplete = true
            } else {
                try await translatePending(model.segments, of: model, job: job)
            }
            guard isCurrent(job) else { return }
            finishFileJob(model)
        } catch {
            guard isCurrent(job) else { return }
            let failure = TranslationFailure.from(error)
            if failure == .cancelled {
                model.phase = .cancelled
            } else {
                log.error("File translation failed: \(failure.localizedDescription, privacy: .public)")
                model.phase = .failed(failure.localizedDescription)
            }
        }
    }

    private func isCurrent(_ job: FileTranslationJob) -> Bool {
        job.generation == fileGeneration && !Task.isCancelled
    }

    private func finishFileJob(_ model: FileTranslationModel) {
        guard model.translatableCount > 0 else {
            model.phase = .failed(model.kind == .image ? "No text was found in the image." : "This file has no text to translate.")
            return
        }
        model.phase = .finished
        if let provider = model.provider, model.translatedCount > 0 {
            registry.remember(provider.id, forTarget: model.targetCode)
        }
    }

    // MARK: - Translating

    /// Translates the segments that have no translation yet, chunk by chunk, updating the window as pieces arrive.
    private func translatePending(_ segments: [DocumentSegment], of model: FileTranslationModel, job: FileTranslationJob) async throws {
        let pending = segments.filter { $0.isTranslatable && model.translations[$0.id] == nil }
        guard !pending.isEmpty else { return }
        if !job.isReady {
            try await prepare(job, for: model)
        }
        guard !job.isSameLanguage, let config = job.config, let provider = job.provider else { return }
        model.phase = .translating
        let chunks = DocumentChunker.chunks(pending, limits: job.limits, firstRequestID: job.nextRequestID)
        job.nextRequestID += chunks.reduce(0) { $0 + $1.pieces.count }
        await glossaries.loadIfNeeded()
        for chunk in chunks {
            guard isCurrent(job) else { throw CancellationError() }
            if usage.isOverCap(config) {
                throw TranslationFailure.capReached
            }
            let request = TranslationRequest(
                segments: chunk.segments, source: model.sourceLanguage, target: model.targetLanguage,
                glossary: glossaries.glossary(source: model.sourceLanguage, target: model.targetLanguage)
            )
            let pieces = Dictionary(chunk.pieces.map { ($0.requestID, $0) }) { first, _ in first }
            for try await event in provider.translate(request) {
                guard isCurrent(job) else { throw CancellationError() }
                switch event {
                case let .segment(translated):
                    guard let piece = pieces[translated.id] else { continue }
                    model.setTranslation(job.add(translated.text, piece: piece, target: model.targetLanguage), for: piece.segmentID)
                case let .usage(used):
                    usage.record(used, for: config.id)
                }
            }
            if model.image != nil {
                renderTranslatedImage(model)
            }
        }
    }

    /// Settles the provider once the first text is known: the source language, the provider's state and limits, the
    /// language pack (offering the download), and for a long file sent to a service that bills, the user's go-ahead.
    private func prepare(_ job: FileTranslationJob, for model: FileTranslationModel) async throws {
        if model.sourceLanguage == nil {
            let sample = model.segments.filter(\.isTranslatable).prefix(40).map(\.text)
            model.sourceLanguage = configuredSource ?? LanguageDetector.dominantLanguage(of: Array(sample))
        }
        if let source = model.sourceLanguage, LanguageCatalog.isSameLanguage(source, model.targetLanguage) {
            job.isSameLanguage = true
            job.isReady = true
            model.note = "Already in \(LanguageCatalog.name(of: model.targetCode))"
            return
        }
        guard let config = registry.config(for: model.providerID), registry.isVisible(config) else {
            throw TranslationFailure.unknownProvider(model.providerID.rawValue)
        }
        if usage.isOverCap(config) {
            throw TranslationFailure.capReached
        }
        let provider = registry.provider(for: config)
        let availability = await provider.availability(source: model.sourceLanguage, target: model.targetLanguage)
        guard isCurrent(job) else { throw CancellationError() }
        if case let .packNotInstalled(source, target) = availability {
            languagePackWindow.present(source: source, target: target) { [weak self, weak model] downloaded in
                guard downloaded, let self, let model, fileModel === model else { return }
                resumeFileTranslation()
            }
        }
        if let failure = availability.failure {
            throw failure
        }
        if !Self.worksOffline(config) {
            let estimate = model.characterCount * max(1, (model.pageCount ?? 1) / max(1, model.currentPage ?? 1))
            if estimate > Self.largeFileCharacters, await !confirmLargeFile(characters: estimate, provider: config.displayName) {
                throw CancellationError()
            }
        }
        job.config = config
        job.provider = provider
        job.limits = ChunkLimits.limits(for: config)
        job.isReady = true
    }

    /// Asks before a long file goes to a provider that may bill for it.
    private func confirmLargeFile(characters: Int, provider: String) async -> Bool {
        let alert = NSAlert()
        alert.messageText = "Translate about \(characters.formatted()) characters with \(provider)?"
        alert.informativeText = """
        This file is long, and \(provider) may charge for it. The monthly cap in Settings → Translation still applies, \
        and you can stop at any time; what is translated by then stays.
        """
        alert.addButton(withTitle: "Translate")
        alert.addButton(withTitle: "Cancel")
        guard let window = fileWindow?.window else { return alert.runModal() == .alertFirstButtonReturn }
        return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
    }

    // MARK: - Images

    private func sampleImageColors(_ model: FileTranslationModel) async {
        guard let image = model.image else { return }
        model.imageColors = await Self.sampleColors(of: image, boxes: model.imageBlocks.map { ($0.id, $0.boundingBox) })
    }

    /// The image with the translations drawn over it, like Translate Area's overlay.
    func renderTranslatedImage(_ model: FileTranslationModel) {
        guard let image = model.image else { return }
        let session = TranslationSessionModel(
            capture: CaptureResult(image: image, kind: .imported, rect: .zero, scale: 1),
            providerID: model.providerID,
            targetLanguage: model.targetLanguage
        )
        session.setBlocks(model.imageBlocks)
        session.colors = model.imageColors
        for block in model.imageBlocks {
            if let translation = model.translations[block.id] {
                session.apply(TranslatedSegment(id: block.id, text: translation))
            }
        }
        model.annotatedImage = Self.renderOffscreen(session)
    }
}
