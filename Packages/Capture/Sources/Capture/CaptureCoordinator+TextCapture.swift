import AppKit
import OrielCore
import SharedUI

/// Capture Text (PLAN §17, ⌃⇧O): select an area, read its text on this Mac and copy it, keeping its line breaks and
/// reading order, so Clipboard History keeps it too. A drag reads as soon as the mouse goes up and a click reads the
/// window under the pointer; ⇧ held at that moment opens the text for editing first, or copies it at once when
/// Settings → Capture opens it for editing.
extension CaptureCoordinator {
    /// What the user picked: the pixels and where they were.
    struct TextArea {
        let image: CGImage
        /// Global CoreGraphics points.
        let rect: CGRect
        let scale: CGFloat
        /// ⇧ was held when the selection was made.
        let isShiftHeld: Bool
    }

    /// Selects an area, reads its text and copies it, or opens it for editing. Does nothing while another capture
    /// runs, or without on-device OCR.
    public func captureText() async {
        guard let recognizer = textRecognizer, !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        guard await ensureScreenRecording() else { return }
        let area: TextArea
        do {
            guard let selected = try await selectTextArea() else { return }
            area = selected
        } catch {
            log.error("Capture Text failed: \(error.localizedDescription, privacy: .private)")
            PermissionPrompt.show(error)
            return
        }
        textHUD.show(over: area.rect)
        do {
            let text = try await readText(in: area.image, using: recognizer)
            textHUD.hide()
            deliver(text: text, editing: settings[CaptureSettings.textOpensPanel] != area.isShiftHeld)
        } catch {
            textHUD.hide()
            log.error("Text recognition failed: \(error.localizedDescription, privacy: .private)")
            Toast.show("The text could not be read", symbol: "exclamationmark.triangle")
        }
    }

    /// The freeze-frame overlay in area mode, confirming on release, then the pixels of the pick.
    func selectTextArea() async throws -> TextArea? {
        let screens = try await prepareSelection(keepsHDR: false, hidesDesktop: hidesDesktop)
        var configuration = OverlayConfiguration(mode: .area)
        configuration.allowsModeSwitch = false
        configuration.confirmsOnRelease = true
        configuration.tools = OverlayTool.confirmTools
        configuration.showsMagnifier = settings[CaptureSettings.showsMagnifier]
        configuration.prompt = settings[CaptureSettings.textOpensPanel]
            ? "Select the text to edit · Hold ⇧ to copy it at once"
            : "Select the text to copy · Hold ⇧ to edit it first"
        let overlay = FreezeFrameOverlay(backdrops: screens.backdrops, windows: screens.windows, configuration: configuration)
        guard case let .area(rect, displayID, _) = await overlay.run() else { return nil }
        let isShiftHeld = NSEvent.modifierFlags.contains(.shift)
        let display = try await picture(of: displayID, in: screens)
        let captured = try crop(rect, from: display, windows: screens.windows, kind: .area, intent: .capture)
        return TextArea(image: captured.result.image, rect: captured.result.rect, scale: captured.result.scale, isShiftHeld: isShiftHeld)
    }

    /// The text in `image`: lines read with Vision's accurate recognizer and language correction, in the language it
    /// detects, then laid out in reading order with hyphenated words joined (`TextLayout`).
    func readText(in image: CGImage, using recognizer: any TextRecognizing) async throws -> String {
        let blocks = try await recognizer.recognize(image, mode: .fast, languages: [])
        return Self.text(from: blocks)
    }

    /// The blocks laid out, asking the spelling dictionary which hyphenated words to join.
    static func text(from blocks: [OCRBlock]) -> String {
        let layout = TextLayout(blocks: blocks)
        let sample = layout.rows.map(\.text).joined(separator: " ")
        return layout.text(dictionaryWords: SpellingDictionary.knownWords(layout.hyphenatedWords, inTextLike: sample))
    }

    /// Copies `text` and says what was copied, or opens it for editing; says so when there is none.
    func deliver(text: String, editing: Bool) {
        guard !text.isEmpty else {
            Toast.show("No text found", symbol: "text.viewfinder")
            return
        }
        if editing {
            textPanel.onCopy = { [weak self] edited in self?.copyShowingPreview(edited) }
            textPanel.show(text)
        } else {
            copyShowingPreview(text)
        }
    }

    func copyShowingPreview(_ text: String) {
        guard !text.isEmpty else { return }
        if Pasteboard.copy(text) {
            Toast.show(TextPreview.copiedMessage(for: text), symbol: "text.viewfinder", duration: .seconds(2.4))
        } else {
            Toast.show("The text could not be copied", symbol: "exclamationmark.triangle")
        }
    }
}
