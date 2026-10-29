@testable import ClipboardHistory
import Foundation
import SharedUI
import Testing

struct PasteComposerTests {
    private func entry(_ text: String, kind: ClipboardKind = .text, content: PasteboardSnapshot? = nil) -> PasteComposer.Entry {
        PasteComposer.Entry(item: Fixtures.item(text, kind: kind), content: content ?? Fixtures.text(text))
    }

    @Test func oneItemPastesAsItWasCopied() throws {
        let formatted = Fixtures.snapshot([
            (ClipboardTypes.plainText, Fixtures.data("hi")),
            (ClipboardTypes.html, Fixtures.data("<b>hi</b>")),
        ])
        let composed = try #require(PasteComposer.compose([entry("hi", kind: .richText, content: formatted)], plainText: false))
        #expect(composed == formatted)
    }

    @Test func plainTextKeepsOnlyTheText() throws {
        let formatted = Fixtures.snapshot([
            (ClipboardTypes.plainText, Fixtures.data("hi")),
            (ClipboardTypes.html, Fixtures.data("<b>hi</b>")),
        ])
        let composed = try #require(PasteComposer.compose([entry("hi", kind: .richText, content: formatted)], plainText: true))
        #expect(composed == Fixtures.text("hi"))
    }

    @Test func plainTextLeavesAnImageAlone() throws {
        let image = try Fixtures.snapshot([(ClipboardTypes.png, Fixtures.png())])
        let composed = try #require(PasteComposer.compose([entry("Image", kind: .image, content: image)], plainText: true))
        #expect(composed == image)
    }

    @Test func severalItemsJoinTheirTextsAndSkipImages() throws {
        let image = try Fixtures.snapshot([(ClipboardTypes.png, Fixtures.png())])
        let entries = [entry("first"), entry("Image", kind: .image, content: image), entry("https://example.com", kind: .link)]
        let composed = try #require(PasteComposer.compose(entries, plainText: false))
        #expect(composed == Fixtures.text("first\nhttps://example.com"))
    }

    @Test func severalFileItemsBecomeOneSetOfFiles() throws {
        var first = Fixtures.item("a.txt", kind: .files)
        first.fileURLs = [URL(filePath: "/tmp/a.txt")]
        var second = Fixtures.item("b.txt", kind: .files)
        second.fileURLs = [URL(filePath: "/tmp/b.txt"), URL(filePath: "/tmp/c.txt")]
        let composed = try #require(PasteComposer.compose(
            [PasteComposer.Entry(item: first, content: Fixtures.text("x")), PasteComposer.Entry(item: second, content: Fixtures.text("y"))],
            plainText: false
        ))
        #expect(composed.items.count == 3)
        #expect(composed.items.map { $0.first?.type } == Array(repeating: ClipboardTypes.fileURL, count: 3))
        #expect(composed.data(for: ClipboardTypes.plainText) == Fixtures.data("/tmp/a.txt"))
    }

    @Test func nothingSelectedComposesNothing() {
        #expect(PasteComposer.compose([], plainText: false) == nil)
    }
}
