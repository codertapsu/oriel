import AppKit
import OCR
import OrielCore
import SharedUI

/// Translate Under Cursor (PLAN §17): while it is on, resting the pointer on text shows its translation in a tooltip
/// beside it. A badge in the menu bar shows that it is on; Esc, the badge's menu or the command turns it off. It reads
/// the screen, so it needs Screen Recording, like Translate Area.
extension TranslationCoordinator {
    /// ⌃⇧U.
    static let cursorShortcut = KeyCombo(keyCode: KeyCode.ansiU, modifiers: [.control, .shift])

    var isTranslatingUnderCursor: Bool {
        cursorController?.isRunning == true
    }

    func toggleTranslateUnderCursor() {
        if isTranslatingUnderCursor {
            stopTranslatingUnderCursor()
        } else {
            startTranslatingUnderCursor()
        }
    }

    func startTranslatingUnderCursor() {
        guard !isTranslatingUnderCursor else { return }
        guard let screenCapture else {
            Toast.show("Translate Under Cursor isn't available in this build.", symbol: "exclamationmark.triangle")
            return
        }
        guard cursorPermissions.hasScreenRecording() else {
            cursorPermissions.explainMissingScreenRecording()
            return
        }
        let controller = CursorTranslationController(environment: cursorEnvironment(capture: screenCapture), tooltip: CursorTooltipPanel())
        controller.onStop = { [weak self] reason in
            self?.tearDownCursor()
            Toast.show(reason, symbol: "exclamationmark.triangle")
        }
        let monitor = CursorEventMonitor()
        monitor.onMove = { [weak controller] point in controller?.pointerMoved(to: point) }
        monitor.onScroll = { [weak controller] in controller?.contentChanged() }
        monitor.onDismiss = { [weak controller] in controller?.dismiss() }
        monitor.onEscape = { [weak self] in self?.stopTranslatingUnderCursor() }
        let watchesKeys = cursorPermissions.hasAccessibility()
        monitor.start(watchesKeys: watchesKeys)
        cursorController = controller
        cursorMonitor = monitor
        cursorStatusItem = CursorStatusItem(
            summary: { [weak self] in self?.cursorSummary ?? "" },
            stop: { [weak self] in self?.stopTranslatingUnderCursor() }
        )
        controller.start(at: CursorEventMonitor.pointerLocation)
        log.info("Translate Under Cursor on (keys watched: \(watchesKeys, privacy: .public))")
        Toast.show("Translate Under Cursor is on. \(cursorStopHint(watchesKeys: watchesKeys))", symbol: "character.cursor.ibeam")
    }

    func stopTranslatingUnderCursor() {
        guard cursorController != nil else { return }
        tearDownCursor()
        Toast.show("Translate Under Cursor is off", symbol: "character.cursor.ibeam")
    }

    private func tearDownCursor() {
        cursorController?.stop()
        cursorController = nil
        cursorMonitor?.stop()
        cursorMonitor = nil
        cursorStatusItem?.remove()
        cursorStatusItem = nil
        log.info("Translate Under Cursor off")
    }

    /// "Esc or ⌃⇧U turns it off." Esc needs Accessibility.
    private func cursorStopHint(watchesKeys: Bool) -> String {
        let shortcut = settings[SettingKey<KeyCombo?>("shortcuts.translateUnderCursor", default: Self.cursorShortcut)]
        switch (watchesKeys, shortcut) {
        case let (true, shortcut?): return "Esc or \(shortcut) turns it off."
        case (true, nil): return "Esc turns it off."
        case let (false, shortcut?): return "\(shortcut) turns it off."
        case (false, nil): return "Its menu-bar icon turns it off."
        }
    }

    /// "Into Japanese with DeepL", for the badge's menu.
    private var cursorSummary: String {
        let target = LanguageCatalog.language(for: settings[TranslationKeys.targetLanguage])
        let code = LanguageCatalog.code(for: target)
        let provider = registry.config(for: registry.preferredProvider(forTarget: code))?.displayName ?? ""
        return provider.isEmpty ? "Into \(LanguageCatalog.name(of: code))" : "Into \(LanguageCatalog.name(of: code)) with \(provider)"
    }

    func cursorEnvironment(capture: @escaping @MainActor (CGRect) async throws -> CGImage) -> CursorTranslationController.Environment {
        let recognizer = textRecognizer
        let hint = settings[TranslationKeys.sourceLanguage].trimmingCharacters(in: .whitespaces)
        let languages = hint.isEmpty ? [] : [hint]
        let clock = ContinuousClock()
        return CursorTranslationController.Environment(
            capture: capture,
            recognize: { image in try await recognizer.recognize(image, mode: .fast, languages: languages) },
            translate: { [weak self] text in
                guard let self else { throw CancellationError() }
                return try await translateUnderCursor(text)
            },
            context: { [weak self] in self?.cursorContext ?? "" },
            unit: { [weak self] in self?.settings[TranslationKeys.cursorUnit] ?? .paragraph },
            screen: { point in
                let cocoa = ScreenGeometry.cocoaPoint(fromCG: point, primaryHeight: ScreenLocator.primaryHeight)
                return NSScreen.screens.first { $0.frame.contains(cocoa) }.map(ScreenLocator.cgFrame(of:))
            },
            hasScreenRecording: { [cursorPermissions] in cursorPermissions.hasScreenRecording() },
            now: { clock.now },
            sleep: { deadline in try await clock.sleep(until: deadline) }
        )
    }

    /// Provider, target, glossary and source setting: what decides a translation besides the text.
    var cursorContext: String {
        let target = LanguageCatalog.code(for: LanguageCatalog.language(for: settings[TranslationKeys.targetLanguage]))
        let provider = registry.preferredProvider(forTarget: target).rawValue
        let glossary = glossaries.activeProjectID?.uuidString ?? ""
        return [provider, target, glossary, settings[TranslationKeys.sourceLanguage]].joined(separator: "|")
    }

    /// Translates one piece of text from under the cursor with the provider Settings would use for the target, the
    /// active glossary, and the source language from Settings or detected from the text.
    func translateUnderCursor(_ text: String) async throws -> CursorTranslation {
        let target = LanguageCatalog.language(for: settings[TranslationKeys.targetLanguage])
        let targetCode = LanguageCatalog.code(for: target)
        let source = configuredSource ?? LanguageDetector.languageCode(of: text).map(Locale.Language.init(identifier:))
        let id = registry.preferredProvider(forTarget: targetCode)
        guard let config = registry.config(for: id), registry.isVisible(config) else {
            throw TranslationFailure.unknownProvider(id.rawValue)
        }
        let result = { (translation: String) in
            CursorTranslation(
                text: text, translation: translation, sourceLanguage: source.map(LanguageCatalog.code(for:)), targetLanguage: targetCode,
                providerName: config.displayName
            )
        }
        if let source, LanguageCatalog.isSameLanguage(source, target) {
            return result(text)
        }
        guard !usage.isOverCap(config) else { throw TranslationFailure.capReached }
        let provider = registry.provider(for: config)
        let availability = await provider.availability(source: source, target: target)
        if case let .packNotInstalled(from, into) = availability, offeredCursorLanguagePacks.insert("\(from)>\(into)").inserted {
            languagePackWindow.present(source: from, target: into) { _ in }
        }
        if let failure = availability.failure {
            throw failure
        }
        await glossaries.loadIfNeeded()
        let request = TranslationRequest(
            segments: [TranslationSegment(id: 1, text: text)], source: source, target: target,
            glossary: glossaries.glossary(source: source, target: target)
        )
        var translation: String?
        for try await event in provider.translate(request) {
            switch event {
            case let .segment(segment) where segment.id == 1: translation = segment.text
            case .segment: break
            case let .usage(used): usage.record(used, for: config.id)
            }
        }
        guard let translation, !translation.isEmpty else { throw TranslationFailure.badResponse("The provider sent no translation.") }
        return result(translation)
    }
}
