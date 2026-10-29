import AppKit
@testable import ClipboardHistory
import SharedUI
import Testing

/// Private pasteboards: macOS's Paste from Other Apps only guards the general one, and the user's clipboard stays as
/// it is.
@MainActor
struct PasteboardReaderTests {
    private func pasteboard(_ snapshot: PasteboardSnapshot) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.codertapsu.oriel.tests.\(UUID().uuidString)"))
        Pasteboard.write(snapshot, announces: false, to: pasteboard)
        return pasteboard
    }

    @Test func readsEveryItemAndKeptType() throws {
        let png = try Fixtures.png()
        let board = pasteboard(PasteboardSnapshot(items: [
            [.init(type: ClipboardTypes.png, data: png), .init(type: ClipboardTypes.tiff, data: Data([1, 2]))],
            [.init(type: ClipboardTypes.plainText, data: Fixtures.data("caption"))],
        ]))
        defer { board.releaseGlobally() }
        guard case let .snapshot(snapshot) = PasteboardReader.read(board) else {
            Issue.record("Nothing was read")
            return
        }
        #expect(snapshot.items.count == 2)
        #expect(snapshot.items[0].map(\.type) == [ClipboardTypes.png])
        #expect(snapshot.data(for: ClipboardTypes.plainText) == Fixtures.data("caption"))
    }

    @Test func aConcealedCopyIsNotRead() {
        let board = pasteboard(Fixtures.snapshot([
            (ClipboardTypes.plainText, Fixtures.data("hunter2")),
            ("org.nspasteboard.ConcealedType", Data()),
        ]))
        defer { board.releaseGlobally() }
        guard case .markedPrivate = PasteboardReader.read(board) else {
            Issue.record("A concealed copy was read")
            return
        }
    }

    @Test func anEmptyPasteboardReadsAsEmpty() {
        let board = NSPasteboard(name: NSPasteboard.Name("com.codertapsu.oriel.tests.\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        board.clearContents()
        guard case .empty = PasteboardReader.read(board) else {
            Issue.record("An empty pasteboard gave a snapshot")
            return
        }
    }
}
