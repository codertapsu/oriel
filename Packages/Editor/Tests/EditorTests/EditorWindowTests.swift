import AppKit
import CoreGraphics
@testable import Editor
import Foundation
import ImageIO
import Testing

/// The window's wiring: key presses reach the session, zoom resizes the canvas. The window is built but never
/// ordered in, so nothing appears on screen.
@MainActor
struct EditorWindowTests {
    private func makeController() throws -> EditorWindowController {
        try EditorWindowController(session: EditorSession(document: TestImages.document(width: 400, height: 300, scale: 2)))
    }

    private func key(_ characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil,
            characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode
        ))
    }

    @Test func theWindowIsBuiltButNotShown() throws {
        let controller = try makeController()
        let window = try #require(controller.window)
        #expect(!window.isVisible)
        #expect(window.contentView?.subviews.count == 5)
        #expect(window.contentMinSize == EditorWindowController.minimumContentSize)
        #expect(controller.windowWillReturnUndoManager(window) === controller.session.undoManager)
        #expect(controller.canvas.accessibilityLabel() == "Screenshot canvas")
    }

    @Test func quickLookPreviewsATemporaryPNGAndRemovesItAfterwards() throws {
        let controller = try makeController()
        #expect(!controller.acceptsPreviewPanelControl(nil))
        let url = try controller.writeQuickLookFile()
        #expect(url.pathExtension == "png" && FileManager.default.fileExists(atPath: url.path))
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(CGSize(width: image.width, height: image.height) == controller.session.outputPixelSize)
        #expect(controller.acceptsPreviewPanelControl(nil))
        controller.removeQuickLookFile()
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
        #expect(controller.quickLookURL == nil)
    }

    @Test func keyPressesOnTheCanvasPickToolsAndEdit() throws {
        let controller = try makeController()
        let session = controller.session
        try controller.canvas.keyDown(with: key("r", keyCode: 15))
        #expect(session.tool == .rectangle)
        session.beginGesture(at: CGPoint(x: 10, y: 10))
        session.continueGesture(to: CGPoint(x: 60, y: 40))
        session.endGesture()
        #expect(session.document.items.count == 1)

        try controller.canvas.keyDown(with: key("\u{7F}", keyCode: 51))
        #expect(session.document.items.isEmpty)
        let window = try #require(controller.window)
        #expect(try window.performKeyEquivalent(with: key("z", keyCode: 6, modifiers: .command)))
        #expect(session.document.items.count == 1)
        #expect(try window.performKeyEquivalent(with: key("z", keyCode: 6, modifiers: [.command, .shift])))
        #expect(session.document.items.isEmpty)
        try controller.canvas.keyDown(with: key("v", keyCode: 9))
        #expect(session.tool == .select)
    }

    @Test func zoomResizesTheCanvasAndFitNeverEnlarges() throws {
        let controller = try makeController()
        let session = controller.session
        let canvasSize = session.layout.canvasSize
        controller.perform(.actualSize)
        #expect(session.zoom == 1 && !session.zoomsToFit)
        #expect(controller.canvas.frame.size == canvasSize)
        controller.perform(.zoomIn)
        #expect(session.zoom == 1.25)
        #expect(controller.canvas.frame.size == CGSize(width: canvasSize.width * 1.25, height: canvasSize.height * 1.25))
        controller.perform(.zoomOut)
        controller.perform(.zoomOut)
        #expect(session.zoom == 0.75)
        controller.perform(.zoomToFit)
        #expect(session.zoomsToFit)
        #expect(session.zoom <= 1)
    }

    @Test func croppingResizesTheCanvasAndKeepsFitting() throws {
        let controller = try makeController()
        let session = controller.session
        controller.perform(.actualSize)
        controller.perform(.tool(.crop))
        session.beginGesture(at: CGPoint(x: 10, y: 10))
        session.continueGesture(to: CGPoint(x: 110, y: 60))
        session.endGesture()
        controller.perform(.confirm)
        #expect(session.layout.canvasSize == CGSize(width: 100, height: 50))
        #expect(controller.canvas.frame.size == CGSize(width: 100, height: 50))
    }

    @Test func aLargeCaptureOpensZoomedToFitTheWindow() throws {
        let image = try #require(TestImages.solid(width: 6000, height: 4000))
        let controller = EditorWindowController(session: EditorSession(document: EditorDocument(base: ImageRef(image: image, scale: 1))))
        let session = controller.session
        let window = try #require(controller.window)
        #expect(session.zoomsToFit)
        #expect(session.zoom < 1)
        let content = try #require(window.contentView?.frame.size)
        #expect(controller.canvas.frame.width <= content.width && controller.canvas.frame.height <= content.height)
        #expect(controller.canvas.frame.width == 6000 * session.zoom)
    }

    @Test func initialWindowSizeFitsTheCanvasWithinTheScreen() {
        let small = EditorWindowController.initialContentSize(for: CGSize(width: 200, height: 100), on: nil)
        #expect(small == EditorWindowController.minimumContentSize)
        let large = EditorWindowController.initialContentSize(for: CGSize(width: 5000, height: 3000), on: nil)
        #expect(large.width <= 1440 && large.height <= 900)
    }
}
