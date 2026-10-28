import Foundation
import ImageIO
@testable import OrielTranslation
import Testing

struct TranslationHistoryStoreTests {
    private func entry(id: UUID = UUID(), daysAgo: Double, translation: String = "Bonjour") -> TranslationHistoryEntry {
        TranslationHistoryEntry(
            id: id, date: Date(timeIntervalSinceNow: -daysAgo * 86400), providerID: "apple", providerName: "Apple Translation",
            sourceLanguage: "en", targetLanguage: "fr", blocks: [.init(source: "Hello", translation: translation)]
        )
    }

    @Test func savesListsPurgesAndDeletesEntries() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "oriel-history-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TranslationHistoryStore(directory: directory)
        let old = entry(daysAgo: 40)
        let recent = entry(daysAgo: 1)
        try await store.add(old, image: TestSupport.image(width: 1200, height: 300))
        try await store.add(recent, image: nil)
        #expect(await store.entries().map(\.id) == [recent.id, old.id])

        let thumbnail = try #require(await store.thumbnailData(for: old.id))
        let source = try #require(CGImageSourceCreateWithData(thumbnail as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 480 && image.height == 120)
        #expect(await store.thumbnailData(for: recent.id) == nil)

        #expect(try await store.purge(olderThanDays: 0) == 0)
        #expect(try await store.purge(olderThanDays: 30) == 1)
        #expect(await store.entries().map(\.id) == [recent.id])
        try await store.delete(recent.id)
        #expect(await store.entries().isEmpty)
        try await store.add(recent, image: nil)
        try await store.deleteAll()
        #expect(await store.entries().isEmpty && !FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func translatingACaptureAgainReplacesItsEntry() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "oriel-history-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TranslationHistoryStore(directory: directory)
        let id = UUID()
        try await store.add(entry(id: id, daysAgo: 0, translation: "Bonjour"), image: nil)
        try await store.add(entry(id: id, daysAgo: 0, translation: "Salut"), image: nil)
        let entries = await store.entries()
        #expect(entries.count == 1 && entries.first?.blocks.first?.translation == "Salut")
        #expect(entries.first?.summary == "Salut")
    }
}
