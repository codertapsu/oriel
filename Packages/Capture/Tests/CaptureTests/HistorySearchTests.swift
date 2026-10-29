@testable import Capture
import CoreGraphics
import Foundation
import OrielCore
import Permissions
import Testing

/// History found by the text OCR read in each capture (PLAN §17): why an entry matched, how tall captures are read,
/// and indexing in the background.
@MainActor
struct HistorySearchTests {
    private func entry(text: String?, app: String? = "Preview", title: String? = nil) throws -> HistoryEntry {
        var entry = try HistoryEntry(result: CaptureResult(
            image: TestImages.quadrants(width: 20, height: 10),
            kind: .area,
            rect: .zero,
            scale: 2,
            windowTitle: title,
            appName: app
        ))
        entry.recognizedText = text
        return entry
    }

    @Test func aSnippetShowsTheTextAroundTheFirstMatch() throws {
        let text = """
        Order 4471 confirmed. Thank you for shopping with us.
        Your invoice total is 1 280 € and it is due on 1 December.
        Questions? Write to support.
        """
        let snippet = try #require(HistorySnippet.make(from: text, terms: ["INVOICE"]))
        #expect(snippet.text == "…with us. Your invoice total is 1 280 € and it is due on 1 December. Questions? Write to…")
        #expect(snippet.highlightedWords == ["invoice"])
    }

    @Test func everySearchedWordInTheSnippetIsMarked() throws {
        let snippet = try #require(HistorySnippet.make(from: "Café au lait, then another café", terms: ["cafe", "lait"]))
        #expect(snippet.text == "Café au lait, then another café")
        #expect(snippet.highlightedWords == ["Café", "lait", "café"])
    }

    @Test func aShortTextIsShownWholeOnOneLine() throws {
        let snippet = try #require(HistorySnippet.make(from: "Total due:\n1 280 €\n\nThank   you", terms: ["thank"]))
        #expect(snippet.text == "Total due: 1 280 € Thank you")
        #expect(snippet.highlightedWords == ["Thank"])
        #expect(HistorySnippet.make(from: "Nothing here", terms: ["invoice"]) == nil)
        #expect(HistorySnippet.make(from: "Anything", terms: []) == nil)
    }

    @Test func theSnippetComesFromTheTextThenTheWindowTitle() throws {
        let both = try entry(text: "Invoice 42 is paid", title: "Invoice.pdf")
        #expect(HistorySearch.snippet(for: both, query: "invoice")?.text == "Invoice 42 is paid")
        let titleOnly = try entry(text: "Nothing to see", title: "Invoice.pdf")
        #expect(HistorySearch.snippet(for: titleOnly, query: "invoice")?.text == "Invoice.pdf")
        // Found by its app: the caption already says so.
        #expect(HistorySearch.snippet(for: titleOnly, query: "preview") == nil)
        #expect(HistorySearch.snippet(for: titleOnly, query: " ") == nil)
    }

    @Test func searchIgnoresCaseAndAccentsInEveryField() throws {
        let entries = try [
            entry(text: "Crème brûlée recipe", app: "Safari"),
            entry(text: nil, app: "Xcode", title: "Package.swift"),
            entry(text: "", app: "Messages"),
        ]
        #expect(HistorySearch.filter(entries, query: "CREME brulee").map(\.id) == [entries[0].id])
        #expect(HistorySearch.filter(entries, query: "package xcode").map(\.id) == [entries[1].id])
        #expect(HistorySearch.filter(entries, query: "area").count == 3)
        #expect(HistorySearch.filter(entries, query: "brulee messages").isEmpty)
        #expect(HistorySearch.terms(in: "  Crème  BRÛLÉE ") == ["creme", "brulee"])
    }

    @Test func tallCapturesAreReadInOverlappingTiles() {
        #expect(TextTiles.rects(width: 1600, height: 900) == [CGRect(x: 0, y: 0, width: 1600, height: 900)])
        #expect(TextTiles.rects(width: 2000, height: 9000) == [
            CGRect(x: 0, y: 0, width: 2000, height: 4096),
            CGRect(x: 0, y: 3968, width: 2000, height: 4096),
            CGRect(x: 0, y: 7936, width: 2000, height: 1064),
        ])
        #expect(TextTiles.rects(width: 8000, height: 1000).map(\.width) == [4096, 4032])
        #expect(TextTiles.rects(width: 0, height: 10).isEmpty)
    }

    @Test func newCapturesAreIndexedInTheBackground() async throws {
        let directory = try TestImages.temporaryDirectory()
        let suite = "com.codertapsu.oriel.history-tests.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        }
        let recognizer = RecordingRecognizer(text: "Invoice 42")
        let coordinator = try CaptureCoordinator(
            settings: SettingsStore(defaults: #require(UserDefaults(suiteName: suite))),
            permissions: PermissionCenter(),
            textRecognizer: recognizer,
            historyDirectory: directory
        )
        let small = try await coordinator.history.add(CaptureResult(
            image: TestImages.quadrants(width: 40, height: 30), kind: .area, rect: .zero, scale: 1
        ))
        let tall = try await coordinator.history.add(CaptureResult(
            image: TestImages.solid(width: 50, height: 5000, red: 1, green: 1, blue: 1), kind: .scrolling, rect: .zero, scale: 1
        ))
        coordinator.indexPendingHistory()
        await coordinator.indexing?.value
        let entries = await coordinator.history.entries()
        let everyEntryIsIndexed = entries.allSatisfy(\.isIndexed)
        #expect(everyEntryIsIndexed)
        #expect(entries.first { $0.id == small.id }?.recognizedText == "Invoice 42")
        #expect(entries.first { $0.id == tall.id }?.recognizedText == "Invoice 42\nInvoice 42")
        // The tall one was read in two tiles, newest first.
        #expect(await recognizer.sizes == [CGSize(width: 50, height: 4096), CGSize(width: 50, height: 1032), CGSize(width: 40, height: 30)])
        #expect(coordinator.indexing == nil)
        #expect(HistorySearch.filter(entries, query: "invoice").count == 2)
    }
}

/// OCR that reads a fixed text and remembers what it was shown.
actor RecordingRecognizer: TextRecognizing {
    let text: String
    private(set) var sizes: [CGSize] = []

    init(text: String) {
        self.text = text
    }

    func recognize(_ image: CGImage, mode _: OCRMode, languages _: [String]) async throws -> [OCRBlock] {
        sizes.append(CGSize(width: image.width, height: image.height))
        return [OCRBlock(id: 1, text: text, boundingBox: .zero, confidence: 1)]
    }
}
