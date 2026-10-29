@testable import Capture
import CoreGraphics
import Foundation
import OrielCore
import Permissions
import Testing

/// Capture Text's command, CLI verb and JSON report (PLAN §17). Nothing here captures the screen: the CLI cases stop
/// before a capture would begin.
@MainActor
struct CaptureTextTests {
    private let suiteName = "com.codertapsu.oriel.capture-text-tests.\(UUID().uuidString)"

    private func makeCoordinator(recognizer: (any TextRecognizing)?) throws -> (CaptureCoordinator, URL) {
        let directory = try TestImages.temporaryDirectory()
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let coordinator = CaptureCoordinator(
            settings: SettingsStore(defaults: defaults),
            permissions: PermissionCenter(),
            textRecognizer: recognizer,
            historyDirectory: directory
        )
        return (coordinator, directory)
    }

    private func cleanUp(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    @Test func theCommandNeedsOnDeviceOCR() throws {
        let (bare, first) = try makeCoordinator(recognizer: nil)
        defer { cleanUp(first) }
        #expect(!bare.commands.contains { $0.id == "captureText" })

        let (full, second) = try makeCoordinator(recognizer: FixedTextRecognizer(text: "Hello"))
        defer { cleanUp(second) }
        let command = try #require(full.commands.first { $0.id == "captureText" })
        #expect(command.title == "Capture Text")
        #expect(command.group == .capture)
        #expect(command.route == "capture/text")
        #expect(command.defaultShortcut == KeyCombo(keyCode: KeyCode.ansiO, modifiers: [.control, .shift]))
        #expect(command.defaultShortcut?.description == "⌃⇧O")
    }

    @Test func theCLIExplainsWhatIsMissing() async throws {
        let (bare, first) = try makeCoordinator(recognizer: nil)
        defer { cleanUp(first) }
        let request = IPCRequest(verb: "capture.text", options: ["rect": "0,0,10,10"])
        let unavailable = await bare.runCaptureText(request)
        #expect(unavailable.status == 1 && unavailable.error == "Text recognition is not available.")

        let (full, second) = try makeCoordinator(recognizer: FixedTextRecognizer(text: "Hello"))
        defer { cleanUp(second) }
        let badRect = await full.runCaptureText(IPCRequest(verb: "capture.text", options: ["rect": "1,2,3"]))
        #expect(badRect.status == 64)
        #expect(full.ipcCommands.map(\.verb) == ["capture.text"])
        #expect(full.ipcCommands.first?.usage == "capture text [--rect x,y,w,h] [--json]")
    }

    @Test func rectsParseLikeTheCLIs() {
        #expect(CaptureCoordinator.parseRect("100, 100, 400, 300") == CGRect(x: 100, y: 100, width: 400, height: 300))
        #expect(CaptureCoordinator.parseRect("-1440,-200,10,20") == CGRect(x: -1440, y: -200, width: 10, height: 20))
        #expect(CaptureCoordinator.parseRect("0,0,0,10") == nil)
        #expect(CaptureCoordinator.parseRect("a,b,c,d") == nil)
    }

    @Test func theReportPlacesLinesOnTheScreenInPoints() throws {
        let blocks = [
            OCRBlock(id: 1, text: "Total", boundingBox: CGRect(x: 20, y: 10, width: 100, height: 24), confidence: 0.98, language: "en"),
            OCRBlock(id: 2, text: "€ 12", boundingBox: CGRect(x: 300, y: 11, width: 61, height: 25), confidence: 0.5),
        ]
        let report = TextCaptureReport(text: "Total\t€ 12", blocks: blocks, area: CGRect(x: -500, y: 100, width: 200, height: 40), scale: 2)
        #expect(report.lines.first == .init(text: "Total", x: -490, y: 105, width: 50, height: 12, confidence: 0.98, language: "en"))
        #expect(report.lines.last == .init(text: "€ 12", x: -350, y: 105.5, width: 30.5, height: 12.5, confidence: 0.5, language: nil))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let json = try #require(String(data: encoder.encode(report), encoding: .utf8))
        #expect(json.hasPrefix(#"{"lines":[{"confidence":0.98,"height":12,"language":"en","text":"Total","width":50,"x":-490,"y":105}"#))
        #expect(json.hasSuffix(#""text":"Total\t€ 12"}"#))
    }

    @Test func textCaptureConfirmsOnReleaseAndCopiesByDefault() {
        #expect(!OverlayConfiguration(mode: .area).confirmsOnRelease)
        #expect(!CaptureSettings.textOpensPanel.defaultValue)
    }
}
