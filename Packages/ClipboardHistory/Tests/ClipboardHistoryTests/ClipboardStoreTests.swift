@testable import ClipboardHistory
import CryptoKit
import Foundation
import SharedUI
import Testing

struct ClipboardStoreTests {
    private let key = SymmetricKey(size: .bits256)

    private func store(in directory: URL, key: SymmetricKey? = nil) -> ClipboardStore {
        ClipboardStore(directory: directory, vault: ClipboardVault(key: key ?? self.key))
    }

    @Test func copiesSurviveARestartAndAreEncryptedOnDisk() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = store(in: directory)
        let secret = "sk-live-0123456789abcdef"
        let item = try #require(try await first.record(
            Fixtures.text(secret),
            label: nil,
            sourceName: "Terminal",
            sourceBundleID: "com.apple.Terminal",
            date: Date()
        ))
        #expect(item.kind == .text)

        let reopened = store(in: directory)
        let index = await reopened.index()
        #expect(index.history.map(\.id) == [item.id])
        #expect(reopened.content(of: item.id) == Fixtures.text(secret))
        // Neither the index nor the contents hold the text in the clear.
        let enumerator = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
        while let url = enumerator.nextObject() as? URL {
            guard let data = try? Data(contentsOf: url) else { continue }
            #expect(data.range(of: Data(secret.utf8)) == nil, "\(url.lastPathComponent) holds the secret in the clear")
        }
    }

    @Test func aDifferentKeySetsTheUnreadableHistoryAside() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await store(in: directory).record(Fixtures.text("hello"), label: nil, sourceName: nil, sourceBundleID: nil, date: Date())
        let stranger = store(in: directory, key: SymmetricKey(size: .bits256))
        #expect(await stranger.index().count == 0)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "unreadable/index.sealed").path))
        try await stranger.record(Fixtures.text("fresh start"), label: nil, sourceName: nil, sourceBundleID: nil, date: Date())
        #expect(await stranger.index().history.map(\.title) == ["fresh start"])
    }

    @Test func imagesGetAThumbnailAndKeepOnlyThePNG() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = store(in: directory)
        let png = try Fixtures.png(width: 400, height: 300)
        let snapshot = Fixtures.snapshot([(ClipboardTypes.png, png), (ClipboardTypes.tiff, Data(repeating: 7, count: 5000))])
        let item = try #require(try await store.record(
            snapshot,
            label: "Screenshot",
            sourceName: "Oriel",
            sourceBundleID: nil,
            date: Date()
        ))
        #expect(item.title == "Screenshot · 400 × 300")
        #expect(item.hasThumbnail)
        let thumbnail = try #require(store.thumbnail(of: item.id))
        #expect(max(thumbnail.width, thumbnail.height) == ClipboardStore.thumbnailPixels)
        #expect(store.content(of: item.id)?.types == [ClipboardTypes.png])
        #expect(await store.unindexedImages().map(\.id) == [item.id])
        try await store.setRecognizedText("Total 12", for: item.id)
        #expect(await store.unindexedImages().isEmpty)
        #expect(await store.index().item(item.id)?.recognizedText == "Total 12")
    }

    @Test func deletedItemsComeBackUntilTheTrashIsEmptied() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = store(in: directory)
        for text in ["one", "two", "three"] {
            try await store.record(Fixtures.text(text), label: nil, sourceName: nil, sourceBundleID: nil, date: Date())
        }
        let two = try #require(await store.index().history.first { $0.title == "two" })
        let deletion = try await store.remove([two.id])
        #expect(await store.index().history.map(\.title) == ["three", "one"])
        #expect(store.content(of: two.id) == nil)
        try await store.restore(deletion)
        #expect(await store.index().history.map(\.title) == ["three", "two", "one"])
        #expect(store.content(of: two.id) == Fixtures.text("two"))

        let again = try await store.remove([two.id])
        await store.emptyTrash()
        try await store.restore(again)
        #expect(await store.index().history.map(\.title) == ["three", "one"])
    }

    @Test func clearingKeepsPinnedItemsUnlessAskedAndPruningFreesFiles() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = store(in: directory)
        for text in ["a", "b", "c", "d"] {
            try await store.record(Fixtures.text(text), label: nil, sourceName: nil, sourceBundleID: nil, date: Date())
        }
        let pinned = try #require(await store.index().history.last)
        try await store.setPinned([pinned.id], true)
        #expect(try await store.prune(ClipboardLimits(items: 2, days: 0, bytes: 0)) == 1)
        #expect(await store.index().history.map(\.title) == ["d", "c"])
        _ = try await store.removeAll(includingPinned: false)
        #expect(await store.index().all.map(\.title) == ["a"])
        _ = try await store.removeAll(includingPinned: true)
        await store.emptyTrash()
        #expect(await store.index().count == 0)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.appending(path: "items").path)
        #expect(leftovers.isEmpty)
    }

    @Test func preparingDeletesFilesNoItemNames() async throws {
        let directory = try Fixtures.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = store(in: directory)
        let kept = try #require(try await store.record(
            Fixtures.text("kept"),
            label: nil,
            sourceName: nil,
            sourceBundleID: nil,
            date: Date()
        ))
        let orphan = directory.appending(path: "items/\(UUID().uuidString).sealed")
        try Data([1, 2, 3]).write(to: orphan)
        await store.prepare()
        #expect(!FileManager.default.fileExists(atPath: orphan.path))
        #expect(store.content(of: kept.id) != nil)
    }
}
