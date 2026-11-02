import AppKit
import Foundation
import OrielCore
import SharedUI

/// The interactive session: the overlay and side panel, translating and re-translating, and their actions.
extension TranslationCoordinator {
    func showOverlay(for model: TranslationSessionModel) {
        let screen = ScreenLocator.screen(containing: model.capture.rect) ?? ScreenLocator.screenUnderMouse
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let captureRect = model.capture.rect.isEmpty ? .zero : ScreenLocator.cocoaRect(fromCG: model.capture.rect)
        let frame = OverlayPlacement.overlayFrame(captureRect: captureRect, pointSize: model.capture.pointSize, visibleFrame: visible)
        let controller = TranslationOverlayController(
            model: model,
            frame: frame,
            toolbarActions: toolbarActions(for: model),
            providerShortcut: { [weak self, weak model] number in
                guard let self, let model, model.providers.indices.contains(number - 1) else { return }
                selectProvider(model.providers[number - 1].id, in: model)
            },
            copyBlock: { block in
                guard let translation = block.translation else { return }
                Pasteboard.copy(translation)
                Toast.show("Copied translation", symbol: "doc.on.doc")
            }
        )
        overlay = controller
        controller.show()
        network.start { [weak model] isOffline in
            model?.isOffline = isOffline
        }
    }

    /// Closes the overlay. The side panel, if open, stays with the session.
    func closeOverlay() {
        job?.cancel()
        job = nil
        generation &+= 1
        overlay?.close()
        overlay = nil
        network.stop()
        if sidePanel?.isVisible != true {
            session = nil
        }
    }

    /// Translates the session's blocks with its current provider and languages, replacing earlier translations. The
    /// latest call wins: an earlier one still waiting or streaming stops at its next step and changes nothing more.
    func runTranslation(_ model: TranslationSessionModel, useImage: Bool) async {
        job?.cancel()
        generation &+= 1
        let current = generation
        model.usesImageInput = useImage
        model.clearTranslations()
        guard let config = registry.config(for: model.providerID), registry.isVisible(config) else {
            model.phase = .failed(TranslationFailure.unknownProvider(model.providerID.rawValue).localizedDescription)
            return
        }
        if usage.isOverCap(config) {
            model.phase = .failed(ProviderAvailability.capReached.message)
            return
        }
        if model.isOffline, !Self.worksOffline(config) {
            model.phase = .failed(ProviderAvailability.offline.message)
            return
        }
        if !useImage, let source = model.sourceLanguage, LanguageCatalog.isSameLanguage(source, model.targetLanguage) {
            for segment in model.segments {
                model.apply(TranslatedSegment(id: segment.id, text: segment.text))
            }
            model.note = "Already in \(LanguageCatalog.name(of: model.targetCode))"
            model.phase = .finished
            return
        }
        if let failure = Self.proBlock(config) {
            model.phase = .failed(failure.localizedDescription)
            return
        }
        let provider = registry.provider(for: config)
        model.phase = .translating
        await glossaries.loadIfNeeded()
        let availability = await provider.availability(source: model.sourceLanguage, target: model.targetLanguage)
        guard generation == current, session === model else { return }
        if case let .packNotInstalled(source, target) = availability {
            model.phase = .failed(availability.message)
            languagePackWindow.present(source: source, target: target) { [weak self, weak model] downloaded in
                guard downloaded, let self, let model, session === model else { return }
                retranslate(model, useImage: useImage)
            }
            return
        }
        guard availability.isAvailable else {
            model.phase = .failed(availability.message)
            return
        }
        let request = TranslationRequest(
            segments: model.segments, source: model.sourceLanguage, target: model.targetLanguage,
            image: useImage ? model.capture.image : nil, glossary: glossaries.glossary(
                source: model.sourceLanguage,
                target: model.targetLanguage
            )
        )
        let task = Task { [weak self] in
            do {
                for try await event in provider.translate(request) {
                    guard let self, generation == current else { throw CancellationError() }
                    switch event {
                    case let .segment(segment): model.apply(segment)
                    case let .usage(used): usage.record(used, for: config.id)
                    }
                }
                try Task.checkCancellation()
                guard let self, generation == current else { return }
                model.phase = .finished
                didFinish(model, with: config)
            } catch {
                let failure = TranslationFailure.from(error)
                if failure != .cancelled, self?.generation == current {
                    model.phase = .failed(failure.localizedDescription)
                }
            }
        }
        job = task
        await task.value
    }

    /// Translates again in the background, for toolbar and side-panel actions.
    func retranslate(_ model: TranslationSessionModel, useImage: Bool) {
        Task { await runTranslation(model, useImage: useImage) }
    }

    /// Remembers the provider for the target language and, when history is on, saves the translation (one entry per
    /// capture, replaced when the capture is translated again).
    private func didFinish(_ model: TranslationSessionModel, with config: ProviderConfig) {
        registry.remember(config.id, forTarget: model.targetCode)
        guard settings[TranslationKeys.historyEnabled] else { return }
        let entry = TranslationHistoryEntry(
            id: model.capture.id,
            date: Date(),
            providerID: config.id.rawValue,
            providerName: config.displayName,
            sourceLanguage: model.sourceLanguage.map(LanguageCatalog.code(for:)),
            targetLanguage: model.targetCode,
            blocks: model.blocks.compactMap { block in block.translation.map { .init(source: block.source, translation: $0) } }
        )
        let image = model.capture.image
        let retention = settings[TranslationKeys.historyRetentionDays]
        let history = history
        let log = log
        Task.detached(priority: .utility) {
            do {
                try await history.add(entry, image: image)
                try await history.purge(olderThanDays: retention)
            } catch {
                log.error("Couldn't save the translation history: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    // MARK: - Actions

    private func toolbarActions(for model: TranslationSessionModel) -> TranslationToolbar.Actions {
        TranslationToolbar.Actions(
            selectProvider: { [weak self, weak model] id in
                guard let model else { return }
                self?.selectProvider(id, in: model)
            },
            selectTarget: { [weak self, weak model] code in
                guard let model else { return }
                self?.selectTarget(code, in: model)
            },
            swap: { [weak self, weak model] in
                guard let model else { return }
                self?.swapLanguages(in: model)
            },
            copyAll: { [weak model] in
                guard let model else { return }
                Self.copyAll(of: model)
            },
            aiVision: { [weak self, weak model] in
                guard let model, ProAccess.shared.check(.aiVision) else { return }
                self?.retranslate(model, useImage: true)
            },
            toggleSidePanel: { [weak self, weak model] in
                guard let model else { return }
                self?.toggleSidePanel(for: model)
            },
            close: { [weak self] in self?.closeOverlay() }
        )
    }

    func selectProvider(_ id: ProviderID, in model: TranslationSessionModel) {
        guard model.providerID != id || !model.isBusy else { return }
        model.providerID = id
        let keepsImage = model.usesImageInput && (model.provider?.capabilities.contains(.imageInput) ?? false)
        retranslate(model, useImage: keepsImage)
    }

    /// A new target becomes the Settings target, and brings back the provider last used for it.
    func selectTarget(_ code: String, in model: TranslationSessionModel) {
        guard code != model.targetCode else { return }
        settings[TranslationKeys.targetLanguage] = code
        model.targetLanguage = Locale.Language(identifier: code)
        model.providerID = registry.preferredProvider(forTarget: code)
        retranslate(model, useImage: false)
    }

    /// Swaps the language pair: the text's language becomes the target. A fixed source language in Settings is
    /// swapped with the target; otherwise the source is detected again.
    func swapLanguages(in model: TranslationSessionModel) {
        guard let source = model.sourceLanguage, !LanguageCatalog.isSameLanguage(source, model.targetLanguage) else { return }
        let oldTarget = model.targetCode
        let newTarget = LanguageCatalog.code(for: source)
        settings[TranslationKeys.targetLanguage] = newTarget
        if configuredSource != nil {
            settings[TranslationKeys.sourceLanguage] = oldTarget
            model.sourceLanguage = Locale.Language(identifier: oldTarget)
        }
        model.targetLanguage = Locale.Language(identifier: newTarget)
        model.providerID = registry.preferredProvider(forTarget: newTarget)
        retranslate(model, useImage: false)
    }

    static func copyAll(of model: TranslationSessionModel) {
        guard !model.allTranslations.isEmpty else { return }
        Pasteboard.copy(model.allTranslations)
        Toast.show("Copied translation", symbol: "doc.on.doc")
    }

    func toggleSidePanel(for model: TranslationSessionModel) {
        if let sidePanel, sidePanel.isVisible {
            sidePanel.close()
            return
        }
        let panel = sidePanel ?? TranslationPanelController(model: model, glossaries: glossaries, actions: panelActions(for: model))
        panel.onClose = { [weak self, weak panel] in
            guard let self, overlay == nil, sidePanel === panel else { return }
            session = nil
            sidePanel = nil
        }
        sidePanel = panel
        panel.show(beside: overlay?.frame, on: overlay?.screen)
    }

    private func panelActions(for model: TranslationSessionModel) -> TranslationPanelView.Actions {
        TranslationPanelView.Actions(
            selectProvider: { [weak self, weak model] id in
                guard let model else { return }
                self?.selectProvider(id, in: model)
            },
            selectTarget: { [weak self, weak model] code in
                guard let model else { return }
                self?.selectTarget(code, in: model)
            },
            selectGlossary: { [weak self, weak model] id in
                guard let self, let model, glossaries.activeProjectID != id else { return }
                glossaries.activeProjectID = id
                retranslate(model, useImage: model.usesImageInput)
            },
            swap: { [weak self, weak model] in
                guard let model else { return }
                self?.swapLanguages(in: model)
            },
            copyAll: { [weak model] in
                guard let model else { return }
                Self.copyAll(of: model)
            },
            copy: { text in
                Pasteboard.copy(text)
                Toast.show("Copied", symbol: "doc.on.doc")
            },
            export: { [weak self, weak model] format in
                guard let model else { return }
                self?.export(model, as: format)
            },
            openFiles: { [weak self] urls in self?.translateFiles(urls) }
        )
    }

    // MARK: - Export

    func export(_ model: TranslationSessionModel, as format: TranslationExporter.Format) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = TranslationExporter.suggestedFileName(for: format)
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        NSApp.activate()
        panel.begin { [weak self, weak model] response in
            guard response == .OK, let url = panel.url, let model else { return }
            self?.write(model, as: format, to: url)
        }
    }

    func exportData(for model: TranslationSessionModel, as format: TranslationExporter.Format) -> Data? {
        switch format {
        case .text:
            return Data(TranslationExporter.plainText(model.blocks).utf8)
        case .markdown:
            let markdown = TranslationExporter.markdown(
                model.blocks, source: model.sourceLanguage.map(LanguageCatalog.code(for:)), target: model.targetCode,
                provider: model.provider?.name ?? model.providerID.rawValue
            )
            return Data(markdown.utf8)
        case .annotatedImage:
            let image = overlay.flatMap { $0.model === model ? $0.annotatedImage() : nil } ?? Self.renderOffscreen(model)
            return image.flatMap { ImageEncoder.data($0, type: .png) }
        }
    }

    private func write(_ model: TranslationSessionModel, as format: TranslationExporter.Format, to url: URL) {
        do {
            guard let data = exportData(for: model, as: format) else { throw TranslationFailure.badResponse("Nothing to export.") }
            try data.write(to: url, options: .atomic)
            Toast.show("Exported \(url.lastPathComponent)", symbol: "square.and.arrow.up")
        } catch {
            log.error("Export failed: \(error.localizedDescription, privacy: .private)")
            Toast.show("Couldn't export: \(error.localizedDescription)", symbol: "exclamationmark.triangle")
        }
    }

    /// The annotated image without an overlay on screen: lays the blocks out in a view that is never shown.
    static func renderOffscreen(_ model: TranslationSessionModel) -> CGImage? {
        let view = TranslationOverlayView(model: model)
        view.frame = CGRect(origin: .zero, size: model.capture.pointSize)
        return OverlayRenderer.annotatedImage(
            model.capture.image,
            layouts: view.layouts(waitingForColors: false),
            pointSize: view.bounds.size
        )
    }
}
