import AppKit
import OrielCore
import SharedUI

/// The file translation window's actions: changing the provider, language or glossary (which translates again),
/// stopping and resuming, copying and exporting.
extension TranslationCoordinator {
    func fileActions() -> FileTranslationActions {
        FileTranslationActions(
            chooseFile: { [weak self] in self?.chooseFileToTranslate() },
            openFiles: { [weak self] urls in self?.translateFiles(urls) },
            selectProvider: { [weak self] id in
                guard let self, let model = fileModel, model.providerID != id else { return }
                model.providerID = id
                retranslateFile()
            },
            selectTarget: { [weak self] code in
                guard let self, let model = fileModel, code != model.targetCode else { return }
                settings[TranslationKeys.targetLanguage] = code
                model.targetLanguage = Locale.Language(identifier: code)
                model.providerID = registry.preferredProvider(forTarget: code)
                retranslateFile()
            },
            selectGlossary: { [weak self] id in
                guard let self, glossaries.activeProjectID != id else { return }
                glossaries.activeProjectID = id
                retranslateFile()
            },
            stop: { [weak self] in self?.stopFileTranslation() },
            translateAgain: { [weak self] in
                guard let self, let model = fileModel else { return }
                if model.phase == .finished {
                    retranslateFile()
                } else {
                    resumeFileTranslation()
                }
            },
            copyAll: { [weak self] in
                guard let model = self?.fileModel, model.translatedCount > 0 else { return }
                Pasteboard.copy(DocumentExporter.plainText(model.segments, translations: model.translations))
                Toast.show("Copied translation", symbol: "doc.on.doc")
            },
            copyImage: { [weak self] in
                guard let image = self?.fileModel?.annotatedImage else { return }
                Pasteboard.copy(image, label: "Translated image")
                Toast.show("Copied image", symbol: "doc.on.doc")
            },
            copy: { text in
                Pasteboard.copy(text)
                Toast.show("Copied", symbol: "doc.on.doc")
            },
            export: { [weak self] format in self?.exportFile(as: format) }
        )
    }

    /// Translates what was read again from the start: the provider, language or glossary changed.
    func retranslateFile() {
        guard let model = fileModel, model.kind != nil else { return }
        stopFileTranslation()
        model.clearTranslations()
        resumeFileTranslation()
    }

    /// Carries on: translates what has no translation yet, reading the file again if it was not read to the end.
    func resumeFileTranslation() {
        guard let model = fileModel, let url = model.url, let kind = model.kind else { return }
        stopFileTranslation()
        model.providers = providerChoices()
        if model.isComplete {
            model.phase = .translating
            runFileJob(model, url: url, kind: kind, reading: false)
        } else {
            model.reopen()
            runFileJob(model, url: url, kind: kind, reading: true)
        }
    }

    // MARK: - Export

    func exportFile(as format: DocumentExportFormat) {
        guard let model = fileModel, let window = fileWindow?.window else { return }
        guard let data = exportData(of: model, as: format) else {
            Toast.show("Nothing to export yet", symbol: "exclamationmark.triangle")
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = DocumentExporter.suggestedFileName(for: model.url, format: format, target: model.targetCode)
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.write(data, to: url)
        }
    }

    func exportData(of model: FileTranslationModel, as format: DocumentExportFormat) -> Data? {
        if format == .image {
            return model.annotatedImage.flatMap { ImageEncoder.data($0, type: .png) }
        }
        guard let kind = model.kind, !model.segments.isEmpty else { return nil }
        let context = DocumentExporter.Context(
            title: model.title,
            kind: kind,
            source: model.sourceLanguage.map(LanguageCatalog.code(for:)),
            target: model.targetCode,
            provider: model.provider?.name ?? model.providerID.rawValue,
            subtitleHeader: model.subtitleHeader
        )
        return DocumentExporter.data(format, segments: model.segments, translations: model.translations, context: context)
    }

    private func write(_ data: Data, to url: URL) {
        let log = log
        Task.detached(priority: .userInitiated) {
            do {
                try data.write(to: url, options: .atomic)
                await MainActor.run { Toast.show("Exported \(url.lastPathComponent)", symbol: "square.and.arrow.up") }
            } catch {
                log.error("File export failed: \(error.localizedDescription, privacy: .private)")
                await MainActor.run { Toast.show("Couldn't export: \(error.localizedDescription)", symbol: "exclamationmark.triangle") }
            }
        }
    }
}
