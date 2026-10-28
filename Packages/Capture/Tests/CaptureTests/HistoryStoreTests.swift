@testable import Capture
import CoreGraphics
import Foundation
import OrielCore
import Testing

struct HistoryStoreTests {
    private func capture(daysAgo days: Double = 0, app: String? = nil, title: String? = nil) throws -> CaptureResult {
        try CaptureResult(
            image: TestImages.quadrants(width: 60, height: 40),
            kind: .area,
            rect: CGRect(x: 10, y: 10, width: 30, height: 20),
            scale: 2,
            date: Date().addingTimeInterval(-days * 86400),
            windowTitle: title,
            appName: app
        )
    }

    @Test func capturesAreStoredNewestFirstAndSurviveARestart() async throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let older = try await store.add(capture(daysAgo: 1, app: "Safari"))
        let newer = try await store.add(capture(app: "Xcode"))
        #expect(await store.entries().map(\.id) == [newer.id, older.id])
        #expect(FileManager.default.fileExists(atPath: store.imageURL(for: newer).path))
        #expect(FileManager.default.fileExists(atPath: store.thumbnailURL(for: newer).path))
        let image = try #require(store.loadImage(for: newer))
        #expect(image.width == 60 && image.height == 40)

        let reopened = HistoryStore(directory: directory)
        let entries = await reopened.entries()
        #expect(entries.map(\.id) == [newer.id, older.id])
        #expect(entries.first?.appName == "Xcode")
        #expect(entries.first?.pixelWidth == 60)
        #expect(entries.first?.scale == 2)
    }

    @Test func recognizedTextMakesEntriesSearchable() async throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let invoice = try await store.add(capture(app: "Preview", title: "Invoice.pdf"))
        let chat = try await store.add(capture(app: "Messages"))
        #expect(await store.unindexed().count == 2)
        try await store.setRecognizedText("Total due: 1 280 €\nThank you", for: invoice.id)
        try await store.setRecognizedText("", for: chat.id)
        #expect(await store.unindexed().isEmpty)

        let entries = await store.entries()
        #expect(HistorySearch.filter(entries, query: "total THANK").map(\.id) == [invoice.id])
        #expect(HistorySearch.filter(entries, query: "invoice").map(\.id) == [invoice.id])
        #expect(HistorySearch.filter(entries, query: "messages").map(\.id) == [chat.id])
        #expect(HistorySearch.filter(entries, query: "  ").count == 2)
        #expect(HistorySearch.filter(entries, query: "total missing").isEmpty)
    }

    @Test func retentionDeletesOldCapturesAndTheirFiles() async throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        let old = try await store.add(capture(daysAgo: 40))
        let recent = try await store.add(capture(daysAgo: 2))
        #expect(try await store.prune(keepingDays: 0) == 0)
        #expect(try await store.prune(keepingDays: 30) == 1)
        #expect(await store.entries().map(\.id) == [recent.id])
        #expect(!FileManager.default.fileExists(atPath: store.imageURL(for: old).path))
        #expect(!FileManager.default.fileExists(atPath: store.thumbnailURL(for: old).path))

        try await store.remove([recent.id])
        #expect(await store.entries().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.imageURL(for: recent).path))
    }

    @Test func clearingRemovesEverything() async throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        try await store.add(capture())
        try await store.add(capture())
        try await store.removeAll()
        #expect(await store.entries().isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files == ["index.json"])
    }

    @Test func expiryIsPure() throws {
        let now = Date()
        let entries = try [capture(daysAgo: 0.5), capture(daysAgo: 8)].map(HistoryEntry.init(result:))
        #expect(HistorySearch.expired(entries, keepingDays: 7, now: now).count == 1)
        #expect(HistorySearch.expired(entries, keepingDays: 1, now: now).count == 1)
        #expect(HistorySearch.expired(entries, keepingDays: 30, now: now).isEmpty)
    }
}
