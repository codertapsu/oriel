import CoreGraphics
import Foundation
import OrielCore

/// The CLI verbs Capture answers itself (PLAN §7.1.8); the app lists them next to its own.
public extension CaptureCoordinator {
    /// `capture text [--rect x,y,w,h] [--json]`: the text in an area, on stdout. With `--rect` it reads that area
    /// without asking (Screen Recording must be granted already); without it the user selects one, as with Capture
    /// Text. Nothing is copied. No text found is exit status 1, unless `--json` was asked for.
    var ipcCommands: [IPCCommandHandler] {
        let text = IPCCommandHandler(verb: "capture.text", usage: "capture text [--rect x,y,w,h] [--json]") { [weak self] request in
            guard let self else { return .failure(request, "Oriel is shutting down.") }
            return await runCaptureText(request)
        }
        return [text]
    }
}

extension CaptureCoordinator {
    func runCaptureText(_ request: IPCRequest) async -> IPCResponse {
        guard let recognizer = textRecognizer else { return .failure(request, "Text recognition is not available.") }
        do {
            let image: CGImage
            let area: CGRect
            let scale: CGFloat
            if let value = request.options["rect"] {
                guard let rect = Self.parseRect(value) else {
                    return .failure(request, "--rect must be x,y,width,height in points, e.g. 100,100,400,300", status: 64)
                }
                let shot = try await captureRect(rect)
                (image, area, scale) = (shot.image, shot.rect, shot.scale)
            } else {
                guard let picked = try await selectTextAreaForCLI() else { return .failure(request, "Cancelled.") }
                (image, area, scale) = (picked.image, picked.rect, picked.scale)
            }
            let blocks = try await recognizer.recognize(image, mode: .fast, languages: [])
            let text = Self.text(from: blocks)
            if request.flag("json") {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let report = TextCaptureReport(text: text, blocks: blocks, area: area, scale: scale)
                return try .ok(request, String(data: encoder.encode(report), encoding: .utf8) ?? "{}")
            }
            return text.isEmpty ? .failure(request, "No text found.") : .ok(request, text)
        } catch {
            return .failure(request, error.localizedDescription)
        }
    }

    /// The selection of Capture Text, for the CLI: nil when cancelled.
    private func selectTextAreaForCLI() async throws -> TextArea? {
        guard !isBusy else { throw CaptureError.failed("Another capture is running.") }
        isBusy = true
        defer { isBusy = false }
        guard await ensureScreenRecording() else { throw CaptureError.screenRecordingDenied }
        return try await selectTextArea()
    }

    /// `x,y,w,h` in global points, as the CLI's parser accepts it.
    nonisolated static func parseRect(_ text: String) -> CGRect? {
        let numbers = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 4, numbers[2] > 0, numbers[3] > 0 else { return nil }
        return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }
}
