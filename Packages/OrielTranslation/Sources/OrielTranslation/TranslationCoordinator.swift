import AppKit
import CoreGraphics
import Foundation
import OCR
import OrielCore
import SwiftUI

/// Screenshot translation for the app (PLAN §1.4, §7.7, §10.5): the interactive capture → OCR → translate → overlay
/// flow, the headless flow behind `oriel translate area --json`, the history window, the Settings pane and the
/// bootstrap import. One instance lives as long as the app.
///
/// Nothing here runs while no translation is open: no timers, no observers (the network monitor starts with an
/// overlay and stops with it).
@MainActor
public final class TranslationCoordinator {
    let settings: SettingsStore
    let textRecognizer: any TextRecognizing
    /// Captures part of the screen, in the global coordinates `CaptureCoordinator.captureRect` takes; set by the app,
    /// for the modes that read the screen themselves (Translate Under Cursor).
    public var screenCapture: (@MainActor (CGRect) async throws -> CGImage)?
    let registry: ProviderRegistry
    let usage: UsageTracker
    let history: TranslationHistoryStore
    let log = Log.logger("translation")

    var session: TranslationSessionModel?
    var overlay: TranslationOverlayController?
    var sidePanel: TranslationPanelController?
    /// The streaming task of the current translation.
    var job: Task<Void, Never>?
    /// Numbers translation runs, so only the latest one changes the session.
    var generation = 0
    let network = NetworkStatusMonitor()
    let languagePackWindow = LanguagePackWindowController()
    private var historyWindow: TranslationHistoryWindowController?
    private var settingsModel: TranslationSettingsModel?

    /// - Parameters:
    ///   - settings: where provider settings, languages, usage counters and history preferences live.
    ///   - keychain: where API keys live (service `provider.<id>`).
    ///   - textRecognizer: OCR, normally `VisionTextRecognizer`.
    public convenience init(settings: SettingsStore, keychain: KeychainStore, textRecognizer: any TextRecognizing) {
        self.init(
            settings: settings,
            secrets: keychain,
            textRecognizer: textRecognizer,
            http: .makeDefault(),
            historyDirectory: AppPaths.translationHistory
        )
    }

    /// The designated initializer, for tests: fake secrets, a stubbed URLSession, a temporary history folder and
    /// substitute providers.
    init(
        settings: SettingsStore,
        secrets: any SecretStore,
        textRecognizer: any TextRecognizing,
        http: HTTPClient,
        historyDirectory: URL,
        providerOverride: ProviderRegistry.ProviderOverride? = nil,
        foundationModelsGate: @escaping @MainActor () -> FeatureGate = { FoundationModelsProvider.gate }
    ) {
        self.settings = settings
        self.textRecognizer = textRecognizer
        registry = ProviderRegistry(
            settings: settings, secrets: secrets, http: http, override: providerOverride, foundationModelsGate: foundationModelsGate
        )
        usage = UsageTracker(settings: settings)
        history = TranslationHistoryStore(directory: historyDirectory)
    }

    // MARK: - Public API

    /// The interactive flow: shows the frozen capture over the captured area at once, recognizes its text, and fills
    /// every block with its translation as the provider streams it in. The toolbar switches provider (pop-up or
    /// ⌘1…⌘9) and target language, swaps languages, copies everything, sends the image to a vision model (AI Vision)
    /// and opens the side panel. Esc closes. Returns when the first translation has finished or failed; the overlay
    /// stays open until the user closes it.
    public func translate(_ capture: CaptureResult) async {
        closeOverlay()
        let target = LanguageCatalog.language(for: settings[TranslationKeys.targetLanguage])
        let model = TranslationSessionModel(
            capture: capture, providerID: registry.preferredProvider(forTarget: LanguageCatalog.code(for: target)), targetLanguage: target
        )
        model.providers = providerChoices()
        session = model
        sidePanel?.close()
        sidePanel = nil
        showOverlay(for: model)
        do {
            let blocks = try await recognize(capture.image)
            guard session === model else { return }
            model.setBlocks(blocks)
            model.sourceLanguage = configuredSource ?? LanguageDetector.dominantLanguage(of: blocks.map(\.text))
            model.colors = await Self.sampleColors(of: capture.image, boxes: blocks.map { ($0.id, $0.boundingBox) })
            guard session === model else { return }
            guard !blocks.isEmpty else {
                let visionHint = model.provider?.capabilities.contains(.imageInput) == true ? " Try AI Vision." : ""
                model.phase = .failed(TranslationFailure.noText.localizedDescription + visionHint)
                return
            }
            await runTranslation(model, useImage: false)
        } catch {
            model.phase = .failed(TranslationFailure.from(error).localizedDescription)
        }
    }

    /// The headless flow for `oriel translate area --json`: OCR, then one translation, with no UI. `target` is a
    /// BCP 47 code (nil: the Settings target); `providerID` names a configured provider (nil: the one Settings would
    /// pick for the target). Throws a `TranslationFailure` when the provider cannot translate, for example
    /// `.packNotInstalled`, which only the interactive flow can fix.
    public func translateHeadless(image: CGImage, target: String?, providerID: String?) async throws -> TranslationOutcome {
        let targetLanguage = LanguageCatalog.language(for: target ?? settings[TranslationKeys.targetLanguage])
        let targetCode = LanguageCatalog.code(for: targetLanguage)
        let id = providerID.map { ProviderID(rawValue: $0) } ?? registry.preferredProvider(forTarget: targetCode)
        guard let config = registry.config(for: id), registry.isVisible(config) else {
            throw TranslationFailure.unknownProvider(id.rawValue)
        }
        guard !usage.isOverCap(config) else { throw TranslationFailure.capReached }
        let blocks = try await recognize(image)
        let source = configuredSource ?? LanguageDetector.dominantLanguage(of: blocks.map(\.text))
        var translations: [Int: String] = [:]
        if let source, LanguageCatalog.isSameLanguage(source, targetLanguage) {
            for block in blocks {
                translations[block.id] = block.text
            }
        } else if !blocks.isEmpty {
            let provider = registry.provider(for: config)
            if let failure = await provider.availability(source: source, target: targetLanguage).failure {
                throw failure
            }
            let request = TranslationRequest(
                segments: blocks.map { TranslationSegment(id: $0.id, text: $0.text) }, source: source, target: targetLanguage,
                glossary: settings[TranslationKeys.glossary]
            )
            for try await event in provider.translate(request) {
                switch event {
                case let .segment(segment): translations[segment.id] = segment.text
                case let .usage(used): usage.record(used, for: config.id)
                }
            }
        }
        log.info("Headless translation with \(config.id.rawValue, privacy: .public): \(translations.count) of \(blocks.count) blocks")
        return TranslationOutcome(
            providerID: config.id.rawValue,
            sourceLanguage: source.map(LanguageCatalog.code(for:)),
            targetLanguage: targetCode,
            blocks: blocks.map { block in
                TranslationOutcome.Block(
                    id: block.id,
                    source: block.text,
                    translation: translations[block.id],
                    box: .init(block.boundingBox)
                )
            }
        )
    }

    /// Opens the history window (it explains how to turn history on when it is off).
    public func showHistory() {
        let window = historyWindow ?? TranslationHistoryWindowController(model: TranslationHistoryModel(store: history, settings: settings))
        historyWindow = window
        window.show()
    }

    /// Settings → Translation.
    public var settingsPane: AnyView {
        let model = settingsModel ?? TranslationSettingsModel(
            settings: settings,
            registry: registry,
            usage: usage,
            openHistory: { [weak self] in self?.showHistory() },
            clearHistory: { [history] in try? await history.deleteAll() }
        )
        settingsModel = model
        return AnyView(TranslationSettingsView(model: model))
    }

    /// Imports the translation part of `bootstrap.json` (PLAN §7.7.5): provider settings into `SettingsStore`, API
    /// keys into the Keychain. Providers with an id that exists already are updated in place.
    public func applyBootstrap(_ providers: [BootstrapProvider], defaultProvider: String?) {
        registry.applyBootstrap(providers, defaultProvider: defaultProvider)
    }

    // MARK: - Shared steps

    /// The source language from Settings, or nil for "detect".
    var configuredSource: Locale.Language? {
        let code = settings[TranslationKeys.sourceLanguage].trimmingCharacters(in: .whitespaces)
        return code.isEmpty ? nil : Locale.Language(identifier: code)
    }

    func recognize(_ image: CGImage) async throws -> [OCRBlock] {
        let hint = settings[TranslationKeys.sourceLanguage].trimmingCharacters(in: .whitespaces)
        return try await textRecognizer.recognize(image, mode: .document, languages: hint.isEmpty ? [] : [hint])
    }

    func providerChoices() -> [TranslationSessionModel.ProviderChoice] {
        registry.selectableConfigs.map { .init(id: $0.id, name: $0.displayName, capabilities: $0.kind.capabilities) }
    }

    /// Samples each block's colours off the main actor; `TranslationSessionModel.wholeImageID` gets the colours of
    /// the whole capture.
    nonisolated static func sampleColors(of image: CGImage, boxes: [(Int, CGRect)]) async -> [Int: BlockColors] {
        await Task.detached(priority: .userInitiated) {
            guard let buffer = PixelBuffer(image: image) else { return [:] }
            var all = Dictionary(boxes, uniquingKeysWith: { first, _ in first })
            all[TranslationSessionModel.wholeImageID] = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            return BlockColors.sample(all, in: buffer)
        }.value
    }

    /// Providers that work without a network: on-device ones and servers on this Mac.
    nonisolated static func worksOffline(_ config: ProviderConfig) -> Bool {
        !config.kind.usesNetwork || Endpoint.isLocal(config.effectiveBaseURL)
    }
}
