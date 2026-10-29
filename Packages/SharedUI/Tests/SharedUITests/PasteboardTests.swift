import AppKit
@testable import SharedUI
import Testing

/// Uses private pasteboards, so the tests never touch the user's clipboard.
@MainActor
struct PasteboardTests {
    private func privatePasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("com.codertapsu.oriel.tests.\(UUID().uuidString)"))
    }

    @Test func snapshotsListTypesOnceAndFindTheFirstMatch() {
        let snapshot = PasteboardSnapshot(items: [
            [.init(type: "public.utf8-plain-text", data: Data("one".utf8)), .init(type: "public.rtf", data: Data("{\\rtf1}".utf8))],
            [.init(type: "public.utf8-plain-text", data: Data("two".utf8))],
        ])
        #expect(snapshot.types == ["public.utf8-plain-text", "public.rtf"])
        #expect(snapshot.data(for: "public.utf8-plain-text") == Data("one".utf8))
        #expect(snapshot.data(for: "public.png") == nil)
        #expect(snapshot.byteCount == 3 + 7 + 3)
        #expect(!snapshot.isEmpty)
        #expect(PasteboardSnapshot(items: [[]]).isEmpty)
        #expect(PasteboardSnapshot(text: "hi").data(for: PasteboardSnapshot.plainText) == Data("hi".utf8))
    }

    @Test func writingPutsEveryItemAndRepresentationOnThePasteboard() throws {
        let pasteboard = privatePasteboard()
        defer { pasteboard.releaseGlobally() }
        let snapshot = PasteboardSnapshot(items: [
            [.init(type: "public.utf8-plain-text", data: Data("hello".utf8)), .init(type: "public.html", data: Data("<b>hello</b>".utf8))],
            [.init(type: "public.utf8-plain-text", data: Data("world".utf8))],
        ])
        #expect(Pasteboard.write(snapshot, to: pasteboard))
        let items = try #require(pasteboard.pasteboardItems)
        #expect(items.count == 2)
        #expect(items[0].string(forType: .string) == "hello")
        #expect(items[0].string(forType: .html) == "<b>hello</b>")
        #expect(items[1].string(forType: .string) == "world")
    }

    @Test func announcedWritesReachEveryListener() async {
        let first = Pasteboard.writes()
        let second = Pasteboard.writes()
        Pasteboard.announce(PasteboardWrite(snapshot: PasteboardSnapshot(text: "copied"), changeCount: 42, label: "Screenshot"))
        var firstIterator = first.makeAsyncIterator()
        var secondIterator = second.makeAsyncIterator()
        let received = await firstIterator.next()
        let alsoReceived = await secondIterator.next()
        #expect(received?.changeCount == 42)
        #expect(received?.label == "Screenshot")
        #expect(alsoReceived?.snapshot == PasteboardSnapshot(text: "copied"))
    }
}
